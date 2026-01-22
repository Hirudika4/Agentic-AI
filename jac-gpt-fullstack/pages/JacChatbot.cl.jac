# Main chatbot page component with Mantine UI (Jaseci theme + logo)

import from react { useState }
import from "@jac-client/utils" { jacIsLoggedIn }
import from "@mantine/core" {
    Box,
    Group,
    Text,
    Paper,
    ScrollArea,
    Badge,
    Loader,
    Button,
    Stack,
    Burger
}
import from "@tabler/icons-react" { IconBook, IconSparkles, IconMessageCircle, IconX }
import from ..hooks.useChat { useChat }
import from ..components.ChatMessage { ChatMessage }
import from ..components.ChatInput { ChatInput }
import from ..components.Sidebar { Sidebar }
import from ..components.DocumentationPanel { DocumentationPanel }

# Main Jac GPT Chatbot component (Jaseci theme)
def:pub JacChatbot() -> any {
    has sidebarOpen: bool = False;
    has docPanelOpen: bool = False;

    # --- Theme tokens (keep INSIDE component to avoid build errors) ---
    BG = "#0f0f10";                  # main background
    TOPBAR_BG = "rgba(20,20,20,0.92)";
    BORDER = "#374151";              # gray-700
    TEXT = "#ffffff";
    MUTED = "#9ca3af";
    MUTED2 = "#6b7280";
    PANEL = "rgba(255,255,255,0.04)";
    PANEL_BORDER = "rgba(255,255,255,0.08)";
    ORANGE = "#f97316";
    ORANGE_DARK = "#ea580c";

    chat = useChat();
    isAuthenticated = jacIsLoggedIn();

    def toggleSidebar() -> None {
        sidebarOpen = not sidebarOpen;
    }

    def toggleDocPanel() -> None {
        docPanelOpen = not docPanelOpen;
    }

    # Build message items
    messageItems = [];
    for msg in chat.messages {
        messageItems.push(<ChatMessage
            key={msg.id}
            message={msg.content}
            isUser={msg.isUser}
            timestamp={msg.timestamp}
        />);
    }

    # Loading indicator
    loadingIndicator = <Group gap="sm" py="md" px="xs">
        <Box style={{
            "width": "32px",
            "height": "32px",
            "borderRadius": "10px",
            "background": "rgba(249,115,22,0.12)",
            "border": "1px solid rgba(249,115,22,0.35)",
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center"
        }}>
            <img
                src="/logo.png"
                style={{
                    "width": "20px",
                    "height": "20px",
                    "objectFit": "contain"
                }}
            />
        </Box>
        <Loader size="sm" type="dots" color="orange" />
        <Text size="sm" c={MUTED}>Thinking...</Text>
    </Group>;

    # Check if we have messages
    hasMessages = False;
    for _ in chat.messages {
        hasMessages = True;
        break;
    }

    loadingContent = None;
    if chat.isLoading {
        loadingContent = loadingIndicator;
    }

    # Guest message count badge (top bar)
    messageCountDisplay = None;
    if not isAuthenticated {
        messageCountDisplay = <Badge
            variant="light"
            radius="sm"
            size="sm"
            styles={{
                "root": {
                    "background": "rgba(249,115,22,0.12)",
                    "border": "1px solid rgba(249,115,22,0.25)",
                    "color": "#fdba74"
                }
            }}
        >
            {chat.messageCount}{" / "}{chat.maxFreeMessages}{" FREE MESSAGES"}
        </Badge>;
    }

    # Messages content
    messagesContent = <EmptyState onSendMessage={chat.handleSendMessage} BG={BG} TEXT={TEXT} MUTED={MUTED} ORANGE={ORANGE} />;
    if hasMessages {
        messagesContent = <Box maw={950} mx="auto" p="md">
            <Stack gap="md">
                {messageItems}
                {loadingContent}
            </Stack>
            <div ref={chat.messagesEndRef} />
        </Box>;
    }

    # Layout widths when docs open
    chatAreaWidth = "100%";
    if docPanelOpen {
        chatAreaWidth = "50%";
    }

    # Doc panel element
    docPanelElement = None;
    if docPanelOpen {
        docPanelElement = <Box style={{
            "width": "50%",
            "borderLeft": "1px solid " + BORDER,
            "background": BG
        }}>
            <DocumentationPanel
                message={chat.lastUserMessage}
                suggestions={chat.docSuggestions}
                isVisible={docPanelOpen}
                onToggle={toggleDocPanel}
            />
        </Box>;
    }

    # Button variant for docs
    docsBtnVariant = "outline";
    if docPanelOpen {
        docsBtnVariant = "filled";
    }

    return <Box style={{
        "display": "flex",
        "height": "100vh",
        "background": BG
    }}>
        <Sidebar
            isOpen={sidebarOpen}
            onToggle={toggleSidebar}
            onNewChat={chat.handleNewChat}
            chatSessions={chat.chatSessions}
            currentSessionId={chat.sessionId}
            onLoadSession={chat.handleLoadSession}
            onDeleteSession={chat.handleDeleteSession}
            isLoading={chat.isLoading}
            messageCount={chat.messageCount}
            maxFreeMessages={chat.maxFreeMessages}
        />

        <Box style={{"flex": "1", "display": "flex", "flexDirection": "column", "minWidth": "0"}}>
            # Top bar
            <Paper
                p="sm"
                px="md"
                radius={0}
                style={{
                    "borderBottom": "1px solid " + BORDER,
                    "background": TOPBAR_BG,
                    "backdropFilter": "blur(10px)"
                }}
            >
                <Group justify="space-between">
                    <Group gap="md">
                        <Burger
                            opened={sidebarOpen}
                            onClick={toggleSidebar}
                            hiddenFrom="lg"
                            size="sm"
                            color="gray"
                        />

                        <Group gap="sm">
                            <Box style={{
                                "width": "32px",
                                "height": "32px",
                                "borderRadius": "10px",
                                "background": "rgba(249,115,22,0.12)",
                                "border": "1px solid rgba(249,115,22,0.35)",
                                "display": "flex",
                                "alignItems": "center",
                                "justifyContent": "center"
                            }}>
                                <img
                                    src="/logo.png"
                                    style={{
                                        "width": "20px",
                                        "height": "20px",
                                        "objectFit": "contain"
                                    }}
                                />
                            </Box>

                            <Text fw={700} size="lg" c={TEXT}>
                                Jac GPT
                            </Text>
                        </Group>
                    </Group>

                    <Group gap="sm">
                        <Button
                            onClick={toggleDocPanel}
                            variant={docsBtnVariant}
                            size="sm"
                            radius="md"
                            leftSection={((<IconBook size={16} />) if not docPanelOpen else (<IconX size={16} />))}
                            styles={{
                                "root": {
                                    "background": (ORANGE if docPanelOpen else "transparent"),
                                    "borderColor": (ORANGE if not docPanelOpen else ORANGE),
                                    "color": (TEXT if docPanelOpen else TEXT),
                                    "boxShadow": (("0 0 20px rgba(249,115,22,0.18)") if docPanelOpen else "none")
                                }
                            }}
                            visibleFrom="md"
                        >
                            {(("Hide Docs") if docPanelOpen else ("Show Docs"))}
                        </Button>

                        {messageCountDisplay}
                    </Group>
                </Group>
            </Paper>

            # Main content + optional docs panel
            <Box style={{"flex": "1", "display": "flex", "overflow": "hidden"}}>
                <Box style={{
                    "flex": "1",
                    "display": "flex",
                    "flexDirection": "column",
                    "minWidth": "0",
                    "width": chatAreaWidth
                }}>
                    <ScrollArea style={{"flex": "1"}} type="scroll">
                        {messagesContent}
                    </ScrollArea>

                    <Box style={{
                        "borderTop": "1px solid " + BORDER,
                        "background": "rgba(20,20,20,0.85)"
                    }}>
                        <ChatInput
                            onSendMessage={chat.handleSendMessage}
                            disabled={False}
                            placeholder="Ask me anything about Jac..."
                            isLoading={chat.isLoading}
                            onStop={chat.handleStopGeneration}
                        />
                    </Box>
                </Box>

                {docPanelElement}
            </Box>
        </Box>
    </Box>;
}

# Empty state component (Jaseci theme)
def EmptyState(onSendMessage: any, BG: str, TEXT: str, MUTED: str, ORANGE: str) -> any {
    suggestions = [
        "What is Jac programming language?",
        "How do I create a walker?",
        "Explain nodes and edges",
        "Show me a byLLM example"
    ];

    return <Box style={{
        "flex": "1",
        "display": "flex",
        "flexDirection": "column",
        "alignItems": "center",
        "justifyContent": "center",
        "padding": "32px",
        "textAlign": "center",
        "background": BG
    }}>
        <Box style={{
            "width": "84px",
            "height": "84px",
            "borderRadius": "22px",
            "background": "rgba(249,115,22,0.12)",
            "border": "1px solid rgba(249,115,22,0.35)",
            "display": "flex",
            "alignItems": "center",
            "justifyContent": "center",
            "marginBottom": "22px",
            "boxShadow": "0 0 40px rgba(249,115,22,0.15)"
        }}>
            <img
                src="/logo.png"
                style={{
                    "width": "38px",
                    "height": "38px",
                    "objectFit": "contain"
                }}
            />
        </Box>

        <Text size="xl" fw={800} c={TEXT} mb="xs">
            Ask me anything about Jac
        </Text>

        <Text size="sm" c={MUTED} maw={520} mb="xl">
            Your AI-powered companion for learning and coding in Jac. I can help with syntax, walkers, nodes, edges, and more!
        </Text>

        <Stack gap="sm" w="100%" maw={520}>
            {suggestions.map(lambda suggestion: any, idx: int -> any {
                return <Button
                    key={idx}
                    variant="outline"
                    radius="md"
                    size="md"
                    fullWidth
                    justify="flex-start"
                    leftSection={<IconMessageCircle size={16} color={MUTED} />}
                    onClick={lambda -> None { onSendMessage(suggestion); }}
                    styles={{
                        "root": {
                            "background": "rgba(249,115,22,0.06)",
                            "borderColor": "rgba(249,115,22,0.25)",
                            "color": "#e5e7eb"
                        }
                    }}
                >
                    {suggestion}
                </Button>;
            })}
        </Stack>
    </Box>;
}
