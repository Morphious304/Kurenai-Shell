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
        target: "shell"
        function closeAll(): void { UiState.closeAll(); }
    }
}
