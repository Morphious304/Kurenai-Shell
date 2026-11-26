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
    property string launcherTab: "apps"      // "apps" | "run" | "prime" | "walls"
    property bool mediaOpen: false
    property bool calendarOpen: false
    property bool powerMenuOpen: false
    property bool clipboardOpen: false
    property bool sysmonOpen: false
    property bool shortcutsOpen: false

    // true while ANY overlay is open (the OSD stays quiet then: the panel already shows the value)
    readonly property bool anyOpen: quickSettingsOpen || notificationsOpen || launcherOpen
                                    || mediaOpen || calendarOpen || powerMenuOpen
                                    || clipboardOpen || sysmonOpen || shortcutsOpen

    function closeAll() {
        quickSettingsOpen = false;
        notificationsOpen = false;
        launcherOpen = false;
        mediaOpen = false;
        calendarOpen = false;
        powerMenuOpen = false;
        clipboardOpen = false;
        sysmonOpen = false;
        shortcutsOpen = false;
    }

    function toggleQuickSettings() { const v = !quickSettingsOpen; closeAll(); quickSettingsOpen = v; }
    function toggleNotifications() { const v = !notificationsOpen; closeAll(); notificationsOpen = v; }
    function toggleLauncher()      { const v = !launcherOpen;      closeAll(); if (v) launcherTab = "apps"; launcherOpen = v; }
    function toggleMedia()         { const v = !mediaOpen;         closeAll(); mediaOpen = v; }
    function toggleCalendar()      { const v = !calendarOpen;      closeAll(); calendarOpen = v; }
    function togglePowerMenu()     { const v = !powerMenuOpen;     closeAll(); powerMenuOpen = v; }
    function toggleClipboard()     { const v = !clipboardOpen;     closeAll(); clipboardOpen = v; }
    function toggleSysmon()        { const v = !sysmonOpen;        closeAll(); sysmonOpen = v; }
    function toggleShortcuts()     { const v = !shortcutsOpen;     closeAll(); shortcutsOpen = v; }
    function openLauncher()        { closeAll(); launcherTab = "apps"; launcherOpen = true; }
    readonly property var launcherTabs: ["apps", "run", "prime", "walls"]
    function validTab(t)           { return launcherTabs.indexOf(t) >= 0; }
    // open the launcher on a given tab (unknown names fall back to "apps")
    function openLauncherTab(t)    { closeAll(); launcherTab = validTab(t) ? t : "apps"; launcherOpen = true; }
    // same key twice closes it; a different tab key while it is open just switches tab
    function toggleLauncherTab(t) {
        const tab = validTab(t) ? t : "apps";
        if (launcherOpen && launcherTab === tab) { launcherOpen = false; return; }
        if (launcherOpen) { launcherTab = tab; return; }
        openLauncherTab(tab);
    }
    function openNotifications()   { closeAll(); notificationsOpen = true; }
}
