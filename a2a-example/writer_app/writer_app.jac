"""
Writer A2A Application
======================
Content writing agent with UI - uses LLM to compose text, then calls the
Reviewer Agent via A2A protocol to get quality feedback before delivering.

Run: jac start writer_app.jac --port 8002

Requires Reviewer running: jac start reviewer_app.jac --port 8001
"""

import json;
import uuid;
import requests;
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");
glob REVIEWER_URL: str = "http://localhost:8001";

# ============================================================================
# A2A Client - For calling external agents
# ============================================================================

obj A2AClient {
    has base_url: str;

    def discover -> dict {
        response = requests.post(f"{self.base_url}/walker/get_agent_card", timeout=10);
        return response.json();
    }

    def send_task(skill_id: str, params: dict) -> dict {
        response = requests.post(
            f"{self.base_url}/walker/a2a_tasks_send",
            json={"skill_id": skill_id, "params": params},
            timeout=30
        );
        return response.json();
    }
}

# ============================================================================
# A2A Protocol Types
# ============================================================================

obj AgentCard {
    has name: str,
        description: str,
        url: str = "",
        skills: list[dict] = [];

    def to_dict -> dict {
        return {
            "name": self.name,
            "description": self.description,
            "url": self.url,
            "skills": self.skills
        };
    }
}

obj ContentResult {
    has topic: str,
        tone: str,
        draft: str,
        review_score: int,
        review_strengths: str,
        review_improvements: str,
        final_version: str;
}

# ============================================================================
# Writer Agent
# ============================================================================

node writer_agent {
    has agent_card: AgentCard = AgentCard(
        name="Content Writer Agent",
        description="Writes content on any topic, then consults a Reviewer Agent via A2A for quality feedback",
        url="http://localhost:8002",
        skills=[
            {
                "id": "create_content",
                "name": "Create Content",
                "description": "Write content on a topic with specified tone, get it reviewed via A2A, and return the final version"
            }
        ]
    );

    has reviewer: A2AClient = A2AClient(base_url=REVIEWER_URL);

    has topic_hints: dict = {
        "artificial intelligence": ["machine learning", "neural networks", "automation", "ethical implications", "transformative potential"],
        "climate change": ["renewable energy", "carbon emissions", "extreme weather", "sustainability", "global cooperation"],
        "remote work": ["productivity", "work-life balance", "digital tools", "team collaboration", "flexibility"],
        "space exploration": ["Mars missions", "private companies", "international cooperation", "scientific discovery", "human curiosity"],
        "healthy eating": ["balanced diet", "whole foods", "meal planning", "nutritional awareness", "long-term wellness"]
    };

    """
    Look up relevant keywords and angles for the given topic.
    Returns a list of suggested themes to incorporate.
    """
    def get_topic_hints(topic: str) -> dict {
        topic_lower = topic.lower();
        for (key, hints) in self.topic_hints.items() {
            if key in topic_lower {
                return {"topic": topic, "suggested_themes": hints};
            }
        }
        return {"topic": topic, "suggested_themes": ["key trends", "real-world impact", "future outlook"]};
    }

    """
    Send the draft content to the Reviewer Agent via A2A for quality feedback.
    Returns the reviewer's score, strengths, improvements, and rewritten version.
    """
    def request_review_via_a2a(content: str, tone: str) -> dict {
        word_count = len(content.split());
        print(f"\n[A2A] Writer -> Reviewer: Sending content for review ({word_count} words, tone: {tone})");

        result = self.reviewer.send_task(
            skill_id="review_content",
            params={"content": content, "tone": tone}
        );

        print(f"[A2A] Reviewer Response: {json.dumps(result, indent=2)}");
        return result;
    }

    """
    Create content on the given topic with the specified tone.
    Steps:
    1. Use get_topic_hints to find relevant themes for the topic
    2. Write a well-structured paragraph (100-150 words) incorporating the themes
    3. Send the draft to the Reviewer Agent via request_review_via_a2a
    4. Use the reviewer's rewritten version as the final_version
    Return a ContentResult with the draft, review feedback, and final version.
    """
    def create_content_llm(topic: str, tone: str) -> ContentResult by llm(
        method="ReAct",
        tools=[self.get_topic_hints, self.request_review_via_a2a]
    );

    def execute_skill(skill_id: str, params: dict) -> dict {
        if skill_id == "create_content" {
            topic = params.get("topic", "artificial intelligence");
            tone = params.get("tone", "professional");

            result = self.create_content_llm(topic, tone);

            return {
                "topic": result.topic,
                "tone": result.tone,
                "draft": result.draft,
                "review": {
                    "score": result.review_score,
                    "strengths": result.review_strengths,
                    "improvements": result.review_improvements
                },
                "final_version": result.final_version
            };
        }
        return {"error": "Unknown skill"};
    }
}

# ============================================================================
# Walkers (API Endpoints)
# ============================================================================

walker :pub get_agent_card {
    can start with `root entry {
        visit [-->(`?writer_agent)];
    }

    can return_card with writer_agent entry {
        report here.agent_card.to_dict();
    }
}

walker :pub discover_reviewer {
    can start with `root entry {
        visit [-->(`?writer_agent)];
    }

    can discover with writer_agent entry {
        report here.reviewer.discover();
    }
}

walker :pub a2a_tasks_send {
    has skill_id: str = "create_content",
        params: dict = {};

    can start with `root entry {
        visit [-->(`?writer_agent)];
    }

    can execute with writer_agent entry {
        result = here.execute_skill(self.skill_id, self.params);
        report {
            "jsonrpc": "2.0",
            "result": {
                "id": str(uuid.uuid4()),
                "state": "completed",
                "data": result
            }
        };
    }
}

walker :pub create_content {
    has topic: str = "artificial intelligence",
        tone: str = "professional";

    can start with `root entry {
        visit [-->(`?writer_agent)];
    }

    can write with writer_agent entry {
        result = here.execute_skill("create_content", {
            "topic": self.topic,
            "tone": self.tone
        });
        report result;
    }
}

walker :pub init_agent {
    can start with `root entry {
        if not [-->(`?writer_agent)] {
            here ++> writer_agent();
            print("Created: writer_agent");
        }
        report {"status": "initialized", "agent": "writer_agent"};
    }
}

# ============================================================================
# Frontend UI (jac-client)
# ============================================================================

cl {
    def:pub app -> JsxElement {
        has initialized: bool = False,
            reviewerAgent: dict = {},
            reviewerConnected: bool = False,
            topic: str = "artificial intelligence",
            tone: str = "professional",
            contentResult: dict = {},
            loading: bool = False,
            discovering: bool = False;

        async def initAgent -> None {
            result = root spawn init_agent();
            if result.reports and result.reports.length > 0 {
                initialized = True;
            }
        }

        async def discoverReviewer -> None {
            discovering = True;
            result = root spawn discover_reviewer();
            if result.reports and result.reports.length > 0 {
                response = result.reports[0];
                if response.ok and response.data and response.data.reports {
                    reviewerAgent = response.data.reports[0];
                    reviewerConnected = True;
                }
            }
            discovering = False;
        }

        async def createContent -> None {
            loading = True;
            result = root spawn create_content(
                topic=topic,
                tone=tone
            );
            if result.reports and result.reports.length > 0 {
                contentResult = result.reports[0];
            }
            loading = False;
        }

        async can with entry {
            await initAgent();
        }

        discoverBtnText = ("Discovering..." if discovering else "Discover Reviewer Agent");
        createBtnText = ("Writing + Reviewing (A2A)..." if loading else "Create Content");
        hasReview = contentResult.review and contentResult.review.score;
        scoreColor = ("#059669" if hasReview and contentResult.review.score >= 7 else "#d97706");

        return
            <div style={{
                "fontFamily": "system-ui, sans-serif",
                "maxWidth": "900px",
                "margin": "0 auto",
                "padding": "2rem"
            }}>
                <div style={{
                    "background": "linear-gradient(135deg, #f59e0b 0%, #d97706 100%)",
                    "color": "white",
                    "padding": "2rem",
                    "borderRadius": "12px",
                    "marginBottom": "2rem"
                }}>
                    <h1 style={{"margin": "0 0 0.5rem 0"}}>
                        Content Writer Agent
                    </h1>
                    <p style={{"margin": "0", "opacity": "0.9"}}>
                        A2A Client on port 8002 - Calls Reviewer Agent for quality feedback
                    </p>
                </div>

                <div style={{
                    "display": "grid",
                    "gridTemplateColumns": "1fr 1fr",
                    "gap": "1.5rem",
                    "marginBottom": "1.5rem"
                }}>
                    <div style={{
                        "background": "#f3f4f6",
                        "padding": "1.5rem",
                        "borderRadius": "8px"
                    }}>
                        <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.1rem"}}>
                            A2A Discovery
                        </h2>
                        <button
                            onClick={lambda -> None { discoverReviewer(); }}
                            disabled={discovering}
                            style={{
                                "background": "#6366f1",
                                "color": "white",
                                "border": "none",
                                "padding": "0.6rem 1.2rem",
                                "borderRadius": "6px",
                                "cursor": "pointer",
                                "marginBottom": "1rem"
                            }}
                        >
                            {discoverBtnText}
                        </button>

                        {reviewerConnected && (
                            <div style={{
                                "background": "#d1fae5",
                                "padding": "1rem",
                                "borderRadius": "6px",
                                "border": "1px solid #10b981"
                            }}>
                                <p style={{"margin": "0 0 0.5rem 0", "color": "#059669", "fontWeight": "bold"}}>
                                    Connected to Reviewer
                                </p>
                                <p style={{"margin": "0", "fontSize": "0.9rem"}}>
                                    <strong>Agent:</strong> {reviewerAgent.name}
                                </p>
                                <p style={{"margin": "0.25rem 0 0 0", "fontSize": "0.9rem"}}>
                                    <strong>URL:</strong> {reviewerAgent.url}
                                </p>
                            </div>
                        )}
                        {not reviewerConnected && (
                            <div style={{
                                "background": "#fef3c7",
                                "padding": "1rem",
                                "borderRadius": "6px"
                            }}>
                                <p style={{"margin": "0", "fontSize": "0.9rem"}}>
                                    Click to discover Reviewer agent
                                </p>
                            </div>
                        )}
                    </div>

                    <div style={{
                        "background": "#fffbeb",
                        "padding": "1.5rem",
                        "borderRadius": "8px",
                        "border": "1px solid #f59e0b"
                    }}>
                        <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.1rem"}}>
                            A2A Communication Flow
                        </h2>
                        <div style={{"fontSize": "0.85rem", "lineHeight": "1.6"}}>
                            <p style={{"margin": "0"}}>1. User submits topic and tone</p>
                            <p style={{"margin": "0.25rem 0"}}>2. Writer LLM looks up topic hints</p>
                            <p style={{"margin": "0.25rem 0"}}>3. Writer LLM composes a draft</p>
                            <p style={{"margin": "0.25rem 0", "color": "#d97706", "fontWeight": "bold"}}>
                                4. Writer → A2A → Reviewer
                            </p>
                            <p style={{"margin": "0.25rem 0", "color": "#8b5cf6", "fontWeight": "bold"}}>
                                5. Reviewer → A2A → Writer
                            </p>
                            <p style={{"margin": "0"}}>6. Writer returns draft + review + final</p>
                        </div>
                    </div>
                </div>

                <div style={{
                    "background": "white",
                    "border": "2px solid #f59e0b",
                    "padding": "1.5rem",
                    "borderRadius": "8px",
                    "marginBottom": "1.5rem"
                }}>
                    <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.2rem"}}>
                        Create Content (with A2A Review)
                    </h2>

                    <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "1rem", "marginBottom": "1rem"}}>
                        <div>
                            <label style={{"display": "block", "marginBottom": "0.5rem", "fontSize": "0.9rem"}}>
                                Topic:
                            </label>
                            <input
                                type="text"
                                value={topic}
                                onChange={lambda e: any -> None { topic = e.target.value; }}
                                placeholder="e.g. artificial intelligence, climate change"
                                style={{
                                    "padding": "0.5rem",
                                    "borderRadius": "4px",
                                    "border": "1px solid #ccc",
                                    "width": "100%",
                                    "boxSizing": "border-box"
                                }}
                            />
                        </div>
                        <div>
                            <label style={{"display": "block", "marginBottom": "0.5rem", "fontSize": "0.9rem"}}>
                                Tone:
                            </label>
                            <select
                                value={tone}
                                onChange={lambda e: any -> None { tone = e.target.value; }}
                                style={{
                                    "padding": "0.5rem",
                                    "borderRadius": "4px",
                                    "border": "1px solid #ccc",
                                    "width": "100%",
                                    "boxSizing": "border-box"
                                }}
                            >
                                <option value="professional">Professional</option>
                                <option value="casual">Casual</option>
                                <option value="academic">Academic</option>
                                <option value="persuasive">Persuasive</option>
                            </select>
                        </div>
                    </div>

                    <button
                        onClick={lambda -> None { createContent(); }}
                        disabled={loading}
                        style={{
                            "background": "#f59e0b",
                            "color": "white",
                            "border": "none",
                            "padding": "0.75rem 1.5rem",
                            "borderRadius": "6px",
                            "cursor": "pointer",
                            "fontSize": "1rem"
                        }}
                    >
                        {createBtnText}
                    </button>

                    {contentResult.draft && (
                        <div style={{"marginTop": "1.5rem"}}>
                            <div style={{
                                "padding": "1.5rem",
                                "background": "#fffbeb",
                                "borderRadius": "8px",
                                "border": "1px solid #f59e0b",
                                "marginBottom": "1rem"
                            }}>
                                <h3 style={{"margin": "0 0 0.5rem 0", "color": "#92400e"}}>
                                    Original Draft
                                </h3>
                                <p style={{"margin": "0", "lineHeight": "1.6", "fontSize": "0.95rem"}}>
                                    {contentResult.draft}
                                </p>
                            </div>

                            {hasReview && (
                                <div style={{
                                    "padding": "1.5rem",
                                    "background": "#f5f3ff",
                                    "borderRadius": "8px",
                                    "border": "1px solid #8b5cf6",
                                    "marginBottom": "1rem"
                                }}>
                                    <div style={{"display": "flex", "alignItems": "center", "gap": "1rem", "marginBottom": "1rem"}}>
                                        <h3 style={{"margin": "0", "color": "#5b21b6"}}>
                                            A2A Review from Reviewer Agent
                                        </h3>
                                        <span style={{
                                            "fontSize": "1.5rem",
                                            "fontWeight": "bold",
                                            "color": scoreColor
                                        }}>
                                            {contentResult.review.score}/10
                                        </span>
                                    </div>
                                    <p style={{"margin": "0 0 0.5rem 0", "fontSize": "0.9rem"}}>
                                        <strong style={{"color": "#059669"}}>Strengths:</strong> {contentResult.review.strengths}
                                    </p>
                                    <p style={{"margin": "0", "fontSize": "0.9rem"}}>
                                        <strong style={{"color": "#d97706"}}>Improvements:</strong> {contentResult.review.improvements}
                                    </p>
                                </div>
                            )}

                            {contentResult.final_version && (
                                <div style={{
                                    "padding": "1.5rem",
                                    "background": "#d1fae5",
                                    "borderRadius": "8px",
                                    "border": "2px solid #10b981"
                                }}>
                                    <h3 style={{"margin": "0 0 0.5rem 0", "color": "#065f46"}}>
                                        Final Version (Post-Review)
                                    </h3>
                                    <p style={{"margin": "0", "lineHeight": "1.6", "fontSize": "0.95rem"}}>
                                        {contentResult.final_version}
                                    </p>
                                </div>
                            )}
                        </div>
                    )}
                </div>

                <div style={{
                    "background": "#fef3c7",
                    "padding": "1rem",
                    "borderRadius": "8px",
                    "fontSize": "0.9rem"
                }}>
                    <strong>How it works:</strong> When you click Create Content, the Writer agent
                    composes a draft using LLM, then makes an A2A call to the Reviewer at
                    http://localhost:8001/walker/a2a_tasks_send to get quality feedback.
                    The reviewer scores the content and provides a rewritten version.
                </div>
            </div>;
    }
}
