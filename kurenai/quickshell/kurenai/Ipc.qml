import QtQuick
import Quickshell
import Quickshell.Io

// Command-line control of the running shell, used by the Hyprland keybinds.
// One shell process owns these; the binds just talk to it:
//
//   qs -c kurenai ipc call launcher toggle
//   qs -c kurenai ipc call notifications toggle
//   qs -c kurenai ipc call notifications dnd          (toggle Do Not Disturb)
//   qs -c kurenai ipc call notifications clear
//   qs -c kurenai ipc call quicksettings toggle
//   qs -c kurenai ipc call media toggle|playpause|next|previous
//   qs -c kurenai ipc call calendar toggle
//   qs -c kurenai ipc call powermenu toggle
//   qs -c kurenai ipc call clipboard toggle|close|pause|resume
//   qs -c kurenai ipc call sysmon toggle|close
//   qs -c kurenai ipc call shortcuts toggle|open|close|rescan|status   (keyboard shortcuts page)
//   qs -c kurenai ipc call osd brightness            (shows the brightness OSD; see `kurenai-ctl media-binds`)
//   qs -c kurenai ipc call shell closeAll
//   qs -c kurenai ipc show                            (lists every target and function)
Scope {
    IpcHandler {
        target: "launcher"
        function toggle(): void { UiState.toggleLauncher(); }
        function open(): void { UiState.openLauncher(); }
        function close(): void { UiState.launcherOpen = false; }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { UiState.toggleNotifications(); }
        function open(): void { UiState.openNotifications(); }
        function close(): void { UiState.notificationsOpen = false; }
        function dnd(): void { NotificationStore.toggleDnd(); }
        function clear(): void { NotificationStore.clearAll(); }
    }

    IpcHandler {
        target: "quicksettings"
        function toggle(): void { UiState.toggleQuickSettings(); }
        function open(): void { UiState.closeAll(); UiState.quickSettingsOpen = true; }
        function close(): void { UiState.quickSettingsOpen = false; }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { UiState.toggleMedia(); }
        function playpause(): void { Media.togglePlaying(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { UiState.toggleCalendar(); }
        function close(): void { UiState.calendarOpen = false; }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void { UiState.togglePowerMenu(); }
        function close(): void { UiState.powerMenuOpen = false; }
    }

    IpcHandler {
        target: "shortcuts"
        function toggle(): void { UiState.toggleShortcuts(); }
        function open(): void { UiState.closeAll(); UiState.shortcutsOpen = true; }
        function close(): void { UiState.shortcutsOpen = false; }
        function rescan(): void { Keybinds.refresh(); }
        function status(): string { return Keybinds.statusText(); }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { OsdState.requestBrightness(); }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { UiState.toggleClipboard(); }
        function close(): void { UiState.clipboardOpen = false; }
        function pause(): void { Clipboard.setPaused(true); }
        function resume(): void { Clipboard.setPaused(false); }
    }

    IpcHandler {
        target: "sysmon"
        function toggle(): void { UiState.toggleSysmon(); }
        function close(): void { UiState.sysmonOpen = false; }
    }

    IpcHandler {
        target: "shell"
        function closeAll(): void { UiState.closeAll(); }
    }
}
