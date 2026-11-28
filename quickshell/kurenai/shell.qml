import QtQuick
import Quickshell

// KURENAI shell entry point. Run with:  qs -c kurenai   (managed start: kurenai-ctl start)
// Phase 4b + 4a.6: bar, notifications, launcher, quick settings, media, calendar, power menu, OSD,
// clipboard history, system monitor, keyboard shortcuts page, IPC.
ShellRoot {
    Component.onCompleted: ThemeCtl.start()      // wallpaper colours: catch up with the current wallpaper

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
    ShortcutsPanel {}
    OsdWindow {}
    ClipboardPanel {}
    SysMonPanel {}

    Ipc {}
}
