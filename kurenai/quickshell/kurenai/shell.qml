import Quickshell

// KURENAI shell entry point. Run with:  qs -c kurenai   (managed start: kurenai-ctl start)
// Phase 2: bar + notification popups/centre + launcher + IPC.
// Phase 3 adds the quick-settings panel next to these.
ShellRoot {
    // one bar per screen
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // single instances: they follow the focused monitor themselves
    NotificationPopups {}
    NotificationCenter {}
    Launcher {}

    Ipc {}
}
