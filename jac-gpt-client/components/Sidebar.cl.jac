"""Sidebar component with chat history and user actions using Mantine UI.
Updated: sidebar is ALWAYS visible on desktop (>=1024px) and toggled only on mobile.
"""

import from react { useState }
import from "@jac-client/utils" { Link, jacIsLoggedIn, jacLogout, useNavigate }
import from "@mantine/core" {
    Box,
    Stack,
    Group,
    Text,
    Button,
    ActionIcon,
    ScrollArea,
    Paper,
    Avatar,
    Tooltip,
    Divider,
    UnstyledButton,
    Badge
}
import from "@mantine/hooks" { useMediaQuery }
import from "@tabler/icons-react" {
    IconPlus,
    IconX,
    IconChevronLeft,
    IconChevronRight,
    IconTrash,
    IconHelp,
    IconLogout,
    IconUserPlus,
    IconLogin,
    IconMessage,
    IconSparkles
}
import from ..hooks.useAuth { getUsernameFromToken }

"""Sidebar with chat history, new chat button, and user actions."""
def:pub Sidebar(
    isOpen: bool,
    onToggle: any,
    onNewChat: any,
    chatSessions: list = [],
    currentSessionId: str = "",
    onLoadSession: any = None,
    onDeleteSession: any = None,
    isLoading: bool = False,
    messageCount: int = 0,
    maxFreeMessages: int = 30
) -> any {

    # --- Responsive / visibility ---
    isDesktop = useMediaQuery("(min-width: 1024px)");
    shouldShow = isDesktop or isOpen;

    # --- Local UI state ---
    has isExpanded: bool = True;

    navigate = useNavigate();
    isAuthenticated = jacIsLoggedIn();
    username = getUsernameFromToken();

    # --- Theme tokens (React-like dark + orange) ---
    BG = "#141414";
    BORDER = "#374151";  # gray-700-ish
    TEXT = "#ffffff";
    MUTED = "#9ca3af";   # gray-400
    MUTED2 = "#6b7280";  # gray-500
    PANEL = "rgba(255,255,255,0.04)";
    PANEL_BORDER = "rgba(255,255,255,0.08)";
    ORANGE = "#f97316";

    def toggleExpanded() -> None {
        isExpanded = not isExpanded;
    }

    def handleLogout() -> None {
        jacLogout();
        navigate("/login");
    }

    def getUserInitials() -> str {
        if username and username != "Guest" {
            return username[0].toUpperCase();
        }
        return "G";
    }

    # Sidebar width based on expanded state
    sidebarWidth = (260 if isExpanded else 60);

    # Mobile overlay (only on mobile)
    mobileOverlay = None;
    if isOpen and not isDesktop {
        mobileOverlay = <Box
            style={{
                "position": "fixed",
                "inset": "0",
                "background": "rgba(0,0,0,0.5)",
                "zIndex": "40"
            }}
            onClick={onToggle}
        />;
    }

    # Sidebar container styles (always visible on desktop)
    sidebarStyle = {
        "position": "fixed",
        "left": "0",
        "top": "0",
        "height": "100vh",
        "width": String(sidebarWidth) + "px",
        "background": BG,
        "borderRight": "1px solid " + BORDER,
        "zIndex": "50",
        "transition": "all 0.3s ease",
        "transform": (("translateX(0)" if shouldShow else "translateX(-100%)"))
    };

    # Logo section (React-like)
    logoSection = <Box p="md" style={{"borderBottom": "1px solid " + BORDER}}>
        <Group justify="space-between">
            {(
                <Group gap="sm" style={{"opacity": (("1" if isExpanded else "0")), "transition": "opacity 0.2s ease"}}>
                    <Box style={{
                        "width": "36px",
                        "height": "36px",
                        "borderRadius": "10px",
                        "background": "linear-gradient(135deg, " + ORANGE + " 0%, #ef4444 100%)",
                        "display": "flex",
                        "alignItems": "center",
                        "justifyContent": "center",
                        "boxShadow": "0 0 14px rgba(249, 115, 22, 0.25)"
                    }}>
                        <IconSparkles size={18} color="white" />
                    </Box>
                    <Box>
                        <Text fw={700} size="sm" c={TEXT}>Jaseci</Text>
                        <Text size="xs" c={MUTED}>Jac programming companion</Text>
                    </Box>
                </Group>
                if isExpanded
                else
                <Box mx="auto" style={{
                    "width": "32px",
                    "height": "32px",
                    "borderRadius": "8px",
                    "background": "linear-gradient(135deg, " + ORANGE + " 0%, #ef4444 100%)",
                    "display": "flex",
                    "alignItems": "center",
                    "justifyContent": "center"
                }}>
                    <IconSparkles size={16} color="white" />
                </Box>
            )}

            <Group gap="xs">
                # Expand/collapse button - desktop only
                <ActionIcon
                    onClick={toggleExpanded}
                    variant="subtle"
                    color="gray"
                    size="sm"
                    radius="md"
                    visibleFrom="lg"
                    style={{"color": MUTED}}
                >
                    {((<IconChevronLeft size={16} />) if isExpanded else (<IconChevronRight size={16} />))}
                </ActionIcon>

                # Close button - mobile only
                <ActionIcon
                    onClick={onToggle}
                    variant="subtle"
                    color="gray"
                    size="sm"
                    radius="md"
                    hiddenFrom="lg"
                    style={{"color": MUTED}}
                >
                    <IconX size={16} />
                </ActionIcon>
            </Group>
        </Group>
    </Box>;

    # New chat button (React-like)
    newChatButton = <Box px="md" py="sm">
        <Button
            onClick={onNewChat}
            disabled={isLoading}
            fullWidth={True}
            variant="outline"
            radius="md"
            leftSection={<IconPlus size={16} />}
            styles={{
                "root": {
                    "justifyContent": "flex-start",
                    "background": "rgba(55, 65, 81, 0.8)",
                    "borderColor": "rgba(75, 85, 99, 1)",
                    "color": TEXT
                },
                "label": {
                    "display": (("block" if isExpanded else "none"))
                },
                "section": {
                    "marginRight": (("8px" if isExpanded else "0px"))
                }
            }}
        >
            {("New Chat" if isExpanded else "")}
        </Button>
    </Box>;

    # Chat sessions list (React-like)
    chatSessionsList = None;
    if isExpanded {
        sessionsContent = <Text size="sm" c={MUTED2} ta="center" py="lg">No chat history yet</Text>;

        if chatSessions.length > 0 {
            sessionsContent = <Stack gap={4}>
                {chatSessions.map(lambda session: any -> any {
                    isCurrentSession = session.id == currentSessionId;

                    return <UnstyledButton
                        key={session.id}
                        onClick={lambda -> None {
                            if not isLoading and onLoadSession {
                                onLoadSession(session.id);
                            }
                        }}
                        style={{
                            "display": "flex",
                            "alignItems": "center",
                            "gap": "8px",
                            "padding": "8px 12px",
                            "borderRadius": "8px",
                            "width": "100%",
                            "background": (("rgba(55, 65, 81, 0.8)" if isCurrentSession else "transparent")),
                            "color": (TEXT if isCurrentSession else "#d1d5db"),
                            "opacity": (("0.5" if isLoading else "1")),
                            "cursor": (("not-allowed" if isLoading else "pointer")),
                            "transition": "all 0.2s ease"
                        }}
                    >
                        <IconMessage size={14} color={MUTED} />
                        <Text
                            size="sm"
                            style={{
                                "flex": "1",
                                "overflow": "hidden",
                                "textOverflow": "ellipsis",
                                "whiteSpace": "nowrap"
                            }}
                            c={(TEXT if isCurrentSession else "#d1d5db")}
                        >
                            {session.title}
                        </Text>

                        <ActionIcon
                            onClick={lambda e: any -> None {
                                e.stopPropagation();
                                if not isLoading and onDeleteSession {
                                    onDeleteSession(session.id);
                                }
                            }}
                            disabled={isLoading}
                            variant="subtle"
                            color="red"
                            size="xs"
                            radius="sm"
                            style={{"opacity": "0.75"}}
                        >
                            <IconTrash size={12} />
                        </ActionIcon>
                    </UnstyledButton>;
                })}
            </Stack>;
        }

        chatSessionsList = <Box px="md" style={{"flex": "1", "overflow": "hidden"}}>
            <Text size="xs" fw={600} c={MUTED} tt="uppercase" mb="sm">Recent Chats</Text>
            <ScrollArea style={{"height": "calc(100vh - 410px)"}} type="scroll">
                {sessionsContent}
            </ScrollArea>
        </Box>;
    }

    # Authenticated section (expanded)
    userSection = None;
    if isAuthenticated and isExpanded {
        userSection = <Box px="md" py="sm">
            <Paper
                p="sm"
                radius="md"
                style={{
                    "background": PANEL,
                    "border": "1px solid " + PANEL_BORDER
                }}
            >
                <Group gap="sm" mb="sm">
                    <Avatar
                        radius="xl"
                        size="sm"
                        style={{
                            "background": ORANGE,
                            "color": "white"
                        }}
                    >
                        {getUserInitials()}
                    </Avatar>
                    <Text size="sm" fw={600} c={TEXT} style={{"flex": "1"}}>{username}</Text>
                </Group>

                <Button
                    onClick={handleLogout}
                    variant="subtle"
                    color="red"
                    fullWidth
                    size="xs"
                    leftSection={<IconLogout size={14} />}
                >
                    Log out
                </Button>
            </Paper>
        </Box>;
    }

    # Guest section (expanded) - React-like free messages + buttons
    guestSection = None;
    if not isAuthenticated and isExpanded {
        guestSection = <Box px="md" py="sm">
            <Paper
                p="sm"
                radius="md"
                style={{
                    "background": PANEL,
                    "border": "1px solid " + PANEL_BORDER
                }}
            >
                <Box
                    style={{
                        "fontSize": "12px",
                        "color": MUTED,
                        "background": "rgba(31, 41, 55, 0.6)",
                        "padding": "10px 12px",
                        "borderRadius": "10px",
                        "marginBottom": "10px"
                    }}
                >
                    {"Free messages: "}{messageCount}{"/"}{maxFreeMessages}
                </Box>

                <Stack gap="xs">
                    <Link to="/register" style={{"textDecoration": "none"}}>
                        <Button
                            fullWidth
                            radius="md"
                            size="sm"
                            leftSection={<IconUserPlus size={16} />}
                            style={{
                                "background": ORANGE,
                                "color": "white"
                            }}
                        >
                            Sign Up
                        </Button>
                    </Link>

                    <Link to="/login" style={{"textDecoration": "none"}}>
                        <Button
                            fullWidth
                            radius="md"
                            size="sm"
                            variant="outline"
                            leftSection={<IconLogin size={16} />}
                            styles={{
                                "root": {
                                    "borderColor": ORANGE,
                                    "color": ORANGE
                                }
                            }}
                        >
                            Sign In
                        </Button>
                    </Link>
                </Stack>
            </Paper>
        </Box>;
    }

    # Collapsed auth buttons
    collapsedAuthSection = None;
    if not isExpanded {
        if isAuthenticated {
            collapsedAuthSection = <Stack gap="xs" align="center" px="xs">
                <Tooltip label="Log out" position="right">
                    <ActionIcon
                        onClick={handleLogout}
                        variant="subtle"
                        color="red"
                        size="lg"
                        radius="md"
                    >
                        <IconLogout size={18} />
                    </ActionIcon>
                </Tooltip>
            </Stack>;
        } else {
            collapsedAuthSection = <Stack gap="xs" align="center" px="xs">
                <Tooltip label="Sign Up" position="right">
                    <Link to="/register">
                        <ActionIcon
                            variant="filled"
                            size="lg"
                            radius="md"
                            style={{"background": ORANGE, "color": "white"}}
                        >
                            <IconUserPlus size={18} />
                        </ActionIcon>
                    </Link>
                </Tooltip>

                <Tooltip label="Sign In" position="right">
                    <Link to="/login">
                        <ActionIcon
                            variant="outline"
                            size="lg"
                            radius="md"
                            style={{"borderColor": ORANGE, "color": ORANGE}}
                        >
                            <IconLogin size={18} />
                        </ActionIcon>
                    </Link>
                </Tooltip>
            </Stack>;
        }
    }

    # Help button
    helpButton = <Box px={(("md" if isExpanded else "xs"))} py="sm">
        <Tooltip label="Help & FAQ" position="right" disabled={isExpanded}>
            <Button
                onClick={lambda -> None { window.open("https://www.jac-lang.org/learn/data_spatial/FAQ/", "_blank"); }}
                variant="subtle"
                fullWidth={isExpanded}
                size={(("sm" if isExpanded else "md"))}
                leftSection={((<IconHelp size={16} />) if isExpanded else None)}
                style={{
                    "justifyContent": (("flex-start" if isExpanded else "center")),
                    "color": MUTED
                }}
            >
                {(("Help & FAQ") if isExpanded else (<IconHelp size={18} />))}
            </Button>
        </Tooltip>
    </Box>;

    # Status indicator (React-like pill)
    statusIndicator = None;
    if isExpanded {
        dotColor = (("#22c55e" if isAuthenticated else ORANGE));
        statusLabel = (("Ready to help" if isAuthenticated else "Guest mode"));

        statusIndicator = <Box px="md" pb="md">
            <Group gap="xs" style={{
                "background": "rgba(31, 41, 55, 0.6)",
                "padding": "10px 12px",
                "borderRadius": "10px"
            }}>
                <Box style={{
                    "width": "8px",
                    "height": "8px",
                    "borderRadius": "50%",
                    "background": dotColor
                }} />
                <Text size="xs" c={MUTED}>
                    {statusLabel}
                </Text>
            </Group>
        </Box>;
    }

    return <>
        {mobileOverlay}

        <Box style={sidebarStyle}>
            <Box style={{"display": "flex", "flexDirection": "column", "height": "100%"}}>
                {logoSection}
                {newChatButton}
                {chatSessionsList}

                <Box style={{"marginTop": "auto"}}>
                    <Divider color={BORDER} />
                    {userSection}
                    {guestSection}
                    {collapsedAuthSection}
                    {helpButton}
                    {statusIndicator}
                </Box>
            </Box>
        </Box>

        # Desktop spacer so main content isn't under fixed sidebar
        <Box style={{"width": String(sidebarWidth) + "px", "flexShrink": "0"}} visibleFrom="lg" />
    </>;
}
