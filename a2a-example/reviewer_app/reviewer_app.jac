"""
Reviewer A2A Application
========================
Content review agent with UI - can be called by external apps via A2A protocol.
Uses LLM to analyze writing quality, tone, clarity, and provide actionable feedback.

Run: jac start reviewer_app.jac --port 8001
"""

import json;
import uuid;
import re;
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

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

obj ReviewResult {
    has score: int,
        strengths: str,
        improvements: str,
        rewritten: str;
}

# ============================================================================
# Reviewer Agent
# ============================================================================

node reviewer_agent {
    has agent_card: AgentCard = AgentCard(
        name="Content Reviewer Agent",
        description="Reviews text for clarity, tone, grammar, and provides improvement suggestions with a rewritten version",
        url="http://localhost:8001",
        skills=[
            {
                "id": "review_content",
                "name": "Review Content",
                "description": "Analyze text quality and provide a score (1-10), strengths, improvements, and a rewritten version"
            }
        ]
    );

    """
    Compute basic text statistics: word count, sentence count,
    average word length, and longest sentence length.
    """
    def analyze_text_stats(text: str) -> dict {
        words: list = text.split();
        word_count: int = len(words);
        raw_sentences: list = re.split(r'[.!?]+', text);
        sentences: list = [s.strip() for s in raw_sentences if s.strip()];
        sentence_count: int = len(sentences);
        total_char: int = sum(len(w) for w in words);
        avg_word_len: float = round(total_char / max(word_count, 1), 1);
        longest: int = 0;
        for s in sentences {
            slen: int = len(s.split());
            if slen > longest {
                longest = slen;
            }
        }
        return {
            "word_count": word_count,
            "sentence_count": sentence_count,
            "avg_word_length": avg_word_len,
            "longest_sentence_words": longest
        };
    }

    """
    Review the given text content written in the specified tone.
    First use analyze_text_stats to get text statistics, then evaluate:
    - Clarity and readability (are sentences concise? is vocabulary appropriate?)
    - Tone consistency (does the writing match the requested tone?)
    - Grammar and structure
    Provide a score from 1-10, list key strengths, suggest specific improvements,
    and rewrite the text incorporating your suggestions.
    """
    def review_content_llm(content: str, tone: str) -> ReviewResult by llm(
        method="ReAct",
        tools=[self.analyze_text_stats]
    );

    def execute_skill(skill_id: str, params: dict) -> dict {
        if skill_id == "review_content" {
            content = params.get("content", "");
            tone = params.get("tone", "professional");

            result = self.review_content_llm(content, tone);

            return {
                "score": result.score,
                "strengths": result.strengths,
                "improvements": result.improvements,
                "rewritten": result.rewritten
            };
        }
        return {"error": "Unknown skill"};
    }
}

# ============================================================================
# Walkers (API Endpoints)
# ============================================================================

walker :pub get_agent_card {
    can start with Root entry {
        visit [-->(?:reviewer_agent)];
    }

    can return_card with reviewer_agent entry {
        report here.agent_card.to_dict();
    }
}

walker :pub a2a_tasks_send {
    has skill_id: str = "review_content",
        params: dict = {};

    can start with Root entry {
        visit [-->(?:reviewer_agent)];
    }

    can execute with reviewer_agent entry {
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

walker :pub review_content {
    has content: str = "",
        tone: str = "professional";

    can start with Root entry {
        visit [-->(?:reviewer_agent)];
    }

    can review with reviewer_agent entry {
        result = here.execute_skill("review_content", {
            "content": self.content,
            "tone": self.tone
        });
        report result;
    }
}

walker :pub init_agent {
    can start with Root entry {
        if not [-->(?:reviewer_agent)] {
            here ++> reviewer_agent();
            print("Created: reviewer_agent");
        }
        report {"status": "initialized", "agent": "reviewer_agent"};
    }
}

# ============================================================================
# Frontend UI (jac-client)
# ============================================================================

cl {
    def:pub app -> JsxElement {
        has initialized: bool = False,
            agentCard: dict = {},
            content: str = "Artificial intelligence is changing the world in many ways. It helps doctors find diseases faster. It makes cars drive themselves. AI can also write stories and make art. Many people think AI will keep getting better and do even more amazing things in the future.",
            tone: str = "professional",
            reviewResult: dict = {},
            loading: bool = False;

        async def initAgent -> None {
            result = root spawn init_agent();
            if result.reports and result.reports.length > 0 {
                initialized = True;
            }
        }

        async def loadAgentCard -> None {
            result = root spawn get_agent_card();
            if result.reports and result.reports.length > 0 {
                agentCard = result.reports[0];
            }
        }

        async def submitReview -> None {
            loading = True;
            result = root spawn review_content(
                content=content,
                tone=tone
            );
            if result.reports and result.reports.length > 0 {
                reviewResult = result.reports[0];
            }
            loading = False;
        }

        async can with entry {
            await initAgent();
            await loadAgentCard();
        }

        btnText = ("Reviewing..." if loading else "Review Content");
        scoreColor = ("#059669" if reviewResult.score and reviewResult.score >= 7 else "#d97706");

        return
            <div style={{
                "fontFamily": "system-ui, sans-serif",
                "maxWidth": "800px",
                "margin": "0 auto",
                "padding": "2rem"
            }}>
                <div style={{
                    "background": "linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%)",
                    "color": "white",
                    "padding": "2rem",
                    "borderRadius": "12px",
                    "marginBottom": "2rem"
                }}>
                    <h1 style={{"margin": "0 0 0.5rem 0"}}>
                        Content Reviewer Agent
                    </h1>
                    <p style={{"margin": "0", "opacity": "0.9"}}>
                        A2A Server running on port 8001 - Reviews content using LLM
                    </p>
                </div>

                <div style={{
                    "background": "#f3f4f6",
                    "padding": "1.5rem",
                    "borderRadius": "8px",
                    "marginBottom": "1.5rem"
                }}>
                    <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.2rem"}}>
                        Agent Card (A2A Discovery)
                    </h2>
                    {agentCard.name && (
                        <div>
                            <p><strong>Name:</strong> {agentCard.name}</p>
                            <p><strong>Description:</strong> {agentCard.description}</p>
                            <p><strong>URL:</strong> {agentCard.url}</p>
                            <p><strong>Skills:</strong> review_content</p>
                        </div>
                    )}
                    {not agentCard.name && (
                        <p>Loading agent card...</p>
                    )}
                </div>

                <div style={{
                    "background": "white",
                    "border": "2px solid #8b5cf6",
                    "padding": "1.5rem",
                    "borderRadius": "8px",
                    "marginBottom": "1.5rem"
                }}>
                    <h2 style={{"margin": "0 0 1rem 0", "fontSize": "1.2rem"}}>
                        Review Content
                    </h2>

                    <div style={{"marginBottom": "1rem"}}>
                        <label style={{"display": "block", "marginBottom": "0.5rem"}}>
                            Tone:
                        </label>
                        <select
                            value={tone}
                            onChange={lambda e: any -> None { tone = e.target.value; }}
                            style={{
                                "padding": "0.5rem",
                                "borderRadius": "4px",
                                "border": "1px solid #ccc",
                                "width": "200px"
                            }}
                        >
                            <option value="professional">Professional</option>
                            <option value="casual">Casual</option>
                            <option value="academic">Academic</option>
                            <option value="persuasive">Persuasive</option>
                        </select>
                    </div>

                    <div style={{"marginBottom": "1rem"}}>
                        <label style={{"display": "block", "marginBottom": "0.5rem"}}>
                            Content to review:
                        </label>
                        <textarea
                            value={content}
                            onChange={lambda e: any -> None { content = e.target.value; }}
                            rows={6}
                            style={{
                                "padding": "0.5rem",
                                "borderRadius": "4px",
                                "border": "1px solid #ccc",
                                "width": "100%",
                                "boxSizing": "border-box",
                                "fontFamily": "system-ui, sans-serif"
                            }}
                        />
                    </div>

                    <button
                        onClick={lambda -> None { submitReview(); }}
                        disabled={loading}
                        style={{
                            "background": "#8b5cf6",
                            "color": "white",
                            "border": "none",
                            "padding": "0.75rem 1.5rem",
                            "borderRadius": "6px",
                            "cursor": "pointer",
                            "fontSize": "1rem"
                        }}
                    >
                        {btnText}
                    </button>

                    {reviewResult.strengths && (
                        <div style={{
                            "marginTop": "1.5rem",
                            "padding": "1.5rem",
                            "background": "#f5f3ff",
                            "borderRadius": "8px",
                            "border": "1px solid #8b5cf6"
                        }}>
                            <div style={{"display": "flex", "alignItems": "center", "gap": "1rem", "marginBottom": "1rem"}}>
                                <span style={{
                                    "fontSize": "2rem",
                                    "fontWeight": "bold",
                                    "color": scoreColor
                                }}>
                                    {reviewResult.score}/10
                                </span>
                                <span style={{"fontSize": "1.1rem", "fontWeight": "bold"}}>
                                    Quality Score
                                </span>
                            </div>

                            <div style={{"marginBottom": "1rem"}}>
                                <p style={{"fontWeight": "bold", "margin": "0 0 0.25rem 0", "color": "#059669"}}>
                                    Strengths:
                                </p>
                                <p style={{"margin": "0", "fontSize": "0.9rem"}}>{reviewResult.strengths}</p>
                            </div>

                            <div style={{"marginBottom": "1rem"}}>
                                <p style={{"fontWeight": "bold", "margin": "0 0 0.25rem 0", "color": "#d97706"}}>
                                    Improvements:
                                </p>
                                <p style={{"margin": "0", "fontSize": "0.9rem"}}>{reviewResult.improvements}</p>
                            </div>

                            <div style={{
                                "background": "#e0e7ff",
                                "padding": "1rem",
                                "borderRadius": "6px"
                            }}>
                                <p style={{"fontWeight": "bold", "margin": "0 0 0.25rem 0", "color": "#4338ca"}}>
                                    Rewritten Version:
                                </p>
                                <p style={{"margin": "0", "fontSize": "0.9rem", "lineHeight": "1.6"}}>
                                    {reviewResult.rewritten}
                                </p>
                            </div>
                        </div>
                    )}
                </div>

                <div style={{
                    "background": "#fef3c7",
                    "padding": "1rem",
                    "borderRadius": "8px",
                    "fontSize": "0.9rem"
                }}>
                    <strong>A2A Endpoint:</strong> Other apps can call this agent at:
                    <code style={{
                        "display": "block",
                        "marginTop": "0.5rem",
                        "background": "#fff",
                        "padding": "0.5rem",
                        "borderRadius": "4px"
                    }}>
                        POST http://localhost:8001/walker/a2a_tasks_send
                    </code>
                </div>
            </div>;
    }
}
