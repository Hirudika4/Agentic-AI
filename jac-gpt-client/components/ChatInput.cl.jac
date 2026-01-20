"""Chat input component with send button using Mantine UI (Jaseci orange theme)."""

import from react { useRef, useEffect }
import from "@mantine/core" {
    Box,
    Group,
    Textarea,
    ActionIcon,
    Paper,
    Tooltip
}
import from "@tabler/icons-react" {
    IconSend,
    IconPlayerStop
}

"""Chat input with auto-expanding textarea."""
def:pub ChatInput(
    onSendMessage: any,
    disabled: bool = False,
    placeholder: str = "Ask me anything about Jac...",
    isLoading: bool = False,
    onStop: any = None
) -> any {
    has inputValue: str = "";
    textareaRef = useRef(None);

    # Theme tokens (keep INSIDE function – Jac client parser dislikes top-level consts)
    BG = "#141414";
    TOPBAR_BG = "rgba(20,20,20,0.95)";
    BORDER = "#374151";
    TEXT = "#ffffff";
    MUTED = "#9ca3af";
    ORANGE = "#f97316";
    ORANGE_DARK = "#ea580c";

    # Auto-resize textarea
    useEffect(lambda -> None {
        if textareaRef.current {
            textareaRef.current.style.height = "auto";
            newHeight = Math.min(textareaRef.current.scrollHeight, 200);
            textareaRef.current.style.height = String(newHeight) + "px";
        }
    }, [inputValue]);

    def handleSubmit(e: any) -> None {
        e.preventDefault();
        if inputValue.trim() and not disabled and not isLoading {
            onSendMessage(inputValue.trim());
            inputValue = "";
            if textareaRef.current {
                textareaRef.current.style.height = "auto";
            }
        }
    }

    def handleKeyDown(e: any) -> None {
        # Submit on Enter, new line on Shift+Enter
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            handleSubmit(e);
        }
    }

    def handleInputChange(e: any) -> None {
        inputValue = e.target.value;
    }

    # Determine button state
    canSend = inputValue.trim() and not disabled and not isLoading;

    # Stop button when loading
    stopButton = <Tooltip label="Stop generating" position="top">
        <ActionIcon
            onClick={onStop}
            variant="filled"
            size="xl"
            radius="xl"
            styles={{
                "root": {
                    "background": "rgba(239, 68, 68, 0.95)",
                    "border": "1px solid rgba(239, 68, 68, 0.35)",
                    "boxShadow": "0 6px 18px rgba(239, 68, 68, 0.18)"
                }
            }}
        >
            <IconPlayerStop size={20} />
        </ActionIcon>
    </Tooltip>;

    # Send button (orange)
    sendButton = <Tooltip label="Send message" position="top" disabled={not canSend}>
        <ActionIcon
            onClick={handleSubmit}
            disabled={not canSend}
            variant="filled"
            size="xl"
            radius="xl"
            styles={{
                "root": {
                    "background": (ORANGE if canSend else "rgba(255,255,255,0.08)"),
                    "color": (TEXT if canSend else MUTED),
                    "border": (("1px solid rgba(249,115,22,0.35)" if canSend else "1px solid rgba(255,255,255,0.10)")),
                    "boxShadow": (("0 8px 22px rgba(249,115,22,0.18)" if canSend else "none")),
                    "transition": "all 0.2s ease"
                }
            }}
        >
            <IconSend size={20} />
        </ActionIcon>
    </Tooltip>;

    return <Paper
        p="md"
        radius={0}
        style={{
            "borderTop": "1px solid " + BORDER,
            "background": TOPBAR_BG,
            "backdropFilter": "blur(10px)"
        }}
    >
        <Box maw={980} mx="auto">
            <form onSubmit={handleSubmit}>
                <Group gap="md" align="flex-end">
                    <Box style={{"flex": "1"}}>
                        <Textarea
                            ref={textareaRef}
                            value={inputValue}
                            onChange={handleInputChange}
                            onKeyDown={handleKeyDown}
                            placeholder={placeholder}
                            disabled={disabled or isLoading}
                            autosize
                            minRows={1}
                            maxRows={6}
                            radius="xl"
                            size="md"
                            styles={{
                                "input": {
                                    "background": "rgba(17,17,17,0.90)",
                                    "border": "1px solid rgba(255,255,255,0.10)",
                                    "color": TEXT,
                                    "fontSize": "15px",
                                    "padding": "14px 18px",
                                    "boxShadow": "0 10px 35px rgba(0,0,0,0.35)",
                                    "transition": "all 0.2s ease"
                                }
                            }}
                        />
                    </Box>

                    {(stopButton if isLoading and onStop else sendButton)}
                </Group>
            </form>

            <Box mt="xs" ta="center">
                <span style={{"fontSize": "11px", "color": "rgba(255,255,255,0.35)"}}>
                    {"Press Enter to send, Shift+Enter for new line"}
                </span>
            </Box>
        </Box>
    </Paper>;
}
