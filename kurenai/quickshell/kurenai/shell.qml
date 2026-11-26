import Quickshell

// KURENAI shell entry point. Run with:  qs -c kurenai   (managed start: kurenai-ctl start)
// Phase 3: bar, notification popups/centre, launcher, quick settings, IPC.
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
    QuickSettings {}

    Ipc {}
}
