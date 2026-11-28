pragma Singleton
import QtQuick
import Quickshell

// Window state: which page is open, the search box, the output drawer, the little "saved" toast.
Singleton {
    id: root

    // id, title, icon (Nerd Font glyph), section, file, words the search also looks for
    readonly property var pages: [
        { id: "overview",      title: "Overview",          icon: "", section: "Shell",     file: "OverviewPage.qml",      words: "status health start stop restart validate backup programs tools" },
        { id: "colours",       title: "Colours",           icon: "", section: "Look",      file: "ColoursPage.qml",       words: "theme wallpaper colours color scheme matugen accent contrast tonal vibrant palette" },
        { id: "appcolours",    title: "App colours",       icon: "", section: "Look",      file: "AppColoursPage.qml",    words: "kitty gtk qt btop yazi zathura neovim nvim spicetify pacsea lazygit git pacman aur firefox apps terminal" },
        { id: "wallpaper",     title: "Wallpaper",         icon: "", section: "Look",      file: "WallpaperPage.qml",     words: "background image awww transition folder picker grid" },
        { id: "launcher",      title: "Launcher",          icon: "", section: "Desktop",   file: "LauncherPage.qml",      words: "apps favourites favorites recent run history prime nvidia terminal docked" },
        { id: "rofi",          title: "Rofi",              icon: "", section: "Desktop",   file: "RofiPage.qml",          words: "rofi theme drun" },
        { id: "panels",        title: "Bar and panels",    icon: "", section: "Desktop",   file: "PanelsPage.qml",        words: "bar panels osd sysmon power brightness calendar media quick settings tools shortcuts glass transparency translucent opacity blur hyprglass" },
        { id: "notifications", title: "Notifications",     icon: "", section: "Desktop",   file: "NotificationsPage.qml", words: "notifications popups mako dunst swaync takeover daemon dnd" },
        { id: "clipboard",     title: "Clipboard",         icon: "", section: "Desktop",   file: "ClipboardPage.qml",     words: "clipboard history cliphist pins wipe purge pause" },
        { id: "keybinds",      title: "Keybinds",          icon: "", section: "System",    file: "KeybindsPage.qml",      words: "keys shortcuts binds chord remap super hotkeys" },
        { id: "hooks",         title: "Startup and hooks", icon: "", section: "System",    file: "HooksPage.qml",         words: "autostart hooks enable disable hyprland.lua session glass hyprglass plugin" },
        { id: "lock",          title: "Lock screen",       icon: "", section: "System",    file: "LockPage.qml",          words: "lock screen fingerprint password pam hypridle preview recover diagnose harden" },
        { id: "display",       title: "Display and input", icon: "", section: "System",    file: "DisplayPage.qml",       words: "monitor resolution scale refresh keyboard layout touchpad mouse repeat" },
        { id: "backup",        title: "Backup and restore", icon: "", section: "Safety",   file: "BackupPage.qml",        words: "backup restore rollback export import undo" },
        { id: "logs",          title: "Logs and checks",   icon: "", section: "Safety",    file: "LogsPage.qml",          words: "logs debug diagnose validate troubleshooting" }
    ]

    // which page shows each settings group (the schema comes from kurenai-conf)
    readonly property var groupPage: ({
        launcher: "launcher", wallpaper: "wallpaper", panels: "panels", osd: "panels", sysmon: "panels",
        power: "panels", shortcuts: "panels", clipboard: "clipboard", notifications: "notifications", lock: "lock"
    })

    property string page: "overview"
    property string query: ""            // the search box
    property string focusKey: ""         // a setting to highlight after a search jump
    property bool drawerOpen: false
    property string toast: ""
    property bool toastError: false

    signal scrollRequest(var item)
    signal focusSearch()

    function pageById(id) {
        for (let i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i];
        return pages[0];
    }
    readonly property var current: pageById(page)

    function go(id, key) {
        page = id;
        query = "";
        focusKey = key || "";
        if (focusKey !== "") focusClear.restart();
    }
    Timer { id: focusClear; interval: 2600; onTriggered: root.focusKey = "" }

    function say(text, isError) {
        toast = text;
        toastError = isError === true;
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: root.toastError ? 6000 : 2200; onTriggered: root.toast = "" }

    // ---- search ------------------------------------------------------------------------------------------------------
    function _hit(hay, terms) {
        hay = hay.toLowerCase();
        for (let i = 0; i < terms.length; i++) if (hay.indexOf(terms[i]) < 0) return false;
        return true;
    }
    // pages first, then individual settings; every typed word has to match
    function search(q) {
        const terms = String(q || "").toLowerCase().split(/\s+/).filter(t => t !== "");
        if (terms.length === 0) return [];
        const out = [];
        for (let i = 0; i < pages.length; i++) {
            const p = pages[i];
            if (_hit(p.title + " " + p.words, terms)) out.push({ kind: "page", title: p.title, sub: p.section, page: p.id, key: "" });
        }
        const sc = Store.schema;
        for (let i = 0; i < sc.length && out.length < 40; i++) {
            const r = sc[i];
            if (_hit(r.label + " " + r.key + " " + r.help, terms)) {
                const pid = groupPage[r.group] || "overview";
                out.push({ kind: "setting", title: r.label, sub: pageById(pid).title + "  ·  " + r.key, page: pid, key: r.key });
            }
        }
        return out;
    }
}
