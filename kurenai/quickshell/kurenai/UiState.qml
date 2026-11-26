pragma Singleton
import QtQuick
import Quickshell

// Shared open/closed flags for every overlay. Only one overlay is open at a time.
// Notification count and Do Not Disturb live in NotificationStore (single source of truth).
Singleton {
    id: root

    property bool quickSettingsOpen: false
    property bool notificationsOpen: false
    property bool launcherOpen: false
    property bool mediaOpen: false
    property bool calendarOpen: false
    property bool powerMenuOpen: false

    // true while ANY overlay is open (the OSD stays quiet then: the panel already shows the value)
    readonly property bool anyOpen: quickSettingsOpen || notificationsOpen || launcherOpen
                                    || mediaOpen || calendarOpen || powerMenuOpen

    function closeAll() {
        quickSettingsOpen = false;
        notificationsOpen = false;
        launcherOpen = false;
        mediaOpen = false;
        calendarOpen = false;
        powerMenuOpen = false;
    }

    function toggleQuickSettings() { const v = !quickSettingsOpen; closeAll(); quickSettingsOpen = v; }
    function toggleNotifications() { const v = !notificationsOpen; closeAll(); notificationsOpen = v; }
    function toggleLauncher()      { const v = !launcherOpen;      closeAll(); launcherOpen = v; }
    function toggleMedia()         { const v = !mediaOpen;         closeAll(); mediaOpen = v; }
    function toggleCalendar()      { const v = !calendarOpen;      closeAll(); calendarOpen = v; }
    function togglePowerMenu()     { const v = !powerMenuOpen;     closeAll(); powerMenuOpen = v; }
    function openLauncher()        { closeAll(); launcherOpen = true; }
    function openNotifications()   { closeAll(); notificationsOpen = true; }
}
