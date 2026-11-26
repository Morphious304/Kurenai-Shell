pragma Singleton
import QtQuick
import Quickshell

// Shared UI state. Phase 1 only the bar reads/writes this; the quick-settings panel,
// notification centre and launcher (later phases) will bind to the same flags.
Singleton {
    id: root

    property bool quickSettingsOpen: false
    property bool notificationsOpen: false
    property bool launcherOpen: false

    property int  notificationCount: 0   // wired to the notification server in phase 2
    property bool dnd: false             // do-not-disturb, phase 2

    function closeAll() {
        quickSettingsOpen = false;
        notificationsOpen = false;
        launcherOpen = false;
    }

    // Only one overlay open at a time.
    function toggleQuickSettings() { const v = !quickSettingsOpen; closeAll(); quickSettingsOpen = v; }
    function toggleNotifications() { const v = !notificationsOpen; closeAll(); notificationsOpen = v; }
    function toggleLauncher()      { const v = !launcherOpen;      closeAll(); launcherOpen = v; }
}
