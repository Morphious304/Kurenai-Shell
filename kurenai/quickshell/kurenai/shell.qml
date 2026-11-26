import Quickshell

// KURENAI shell entry point. Run with:  qs -c kurenai   (managed start: kurenai-ctl start)
// Phase 4a: bar, notification popups/centre, launcher, quick settings, media, calendar, power menu, OSD, IPC.
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
    MediaPanel {}
    CalendarPanel {}
    PowerMenu {}
    OsdWindow {}

    Ipc {}
}
