pragma Singleton
import QtQuick
import Quickshell

// Shared open/closed flags for every overlay. Only one overlay is open at a time.
// Notification count and Do Not Disturb live in NotificationStore (single source of truth).
Singleton {
    id: root

    property bool quickSettingsOpen: false   // phase 3
    property bool notificationsOpen: false
    property bool launcherOpen: false

    function closeAll() {
        quickSettingsOpen = false;
        notificationsOpen = false;
        launcherOpen = false;
    }

    function toggleQuickSettings() { const v = !quickSettingsOpen; closeAll(); quickSettingsOpen = v; }
    function toggleNotifications() { const v = !notificationsOpen; closeAll(); notificationsOpen = v; }
    function toggleLauncher()      { const v = !launcherOpen;      closeAll(); launcherOpen = v; }
    function openLauncher()        { closeAll(); launcherOpen = true; }
    function openNotifications()   { closeAll(); notificationsOpen = true; }
}
