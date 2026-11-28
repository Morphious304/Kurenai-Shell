pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// KURENAI behaviour settings (things you might want to change that are not visual design).
// Design tokens (colours, sizes, fonts) live in Theme.qml.
//
// The values written here are the DEFAULTS. Your changes live in ~/.config/kurenai/settings.json (one line per changed
// setting) and are read live: change one with `kurenai-conf set KEY VALUE` or in the KURENAI settings window, and the shell
// follows without a restart. A missing file, a missing key or a value of the wrong type simply leaves the default in place.
// (Editing a default below still works, but a value in settings.json wins.)
Singleton {
    id: root

    // ---- your overrides ---------------------------------------------------------------------------------
    readonly property string settingsFile:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/kurenai/settings.json"
    property var _o: ({})

    function _parse(t) {
        try {
            const d = JSON.parse(t);
            _o = (d && typeof d === "object" && !Array.isArray(d)) ? d : ({});
        } catch (e) {
            _o = ({});          // unreadable file: every default stays in place
        }
    }
    FileView {
        id: overrides
        path: root.settingsFile
        watchChanges: true
        printErrors: false
        onFileChanged: overrides.reload()
        onLoaded: root._parse(overrides.text())
        onLoadFailed: error => root._parse("{}")      // no file yet = defaults
    }

    // typed readers: a value of the wrong type is ignored
    function _b(k, d) { const v = _o[k]; return typeof v === "boolean" ? v : d; }
    function _i(k, d) { const v = _o[k]; return (typeof v === "number" && isFinite(v)) ? Math.round(v) : d; }
    function _r(k, d) { const v = _o[k]; return (typeof v === "number" && isFinite(v)) ? v : d; }
    function _s(k, d) { const v = _o[k]; return typeof v === "string" ? v : d; }
    function _l(k, d) { const v = _o[k]; return (Array.isArray(v) && v.every(x => typeof x === "string")) ? v : d; }

    // ---- launcher ----------------------------------------------------------
    readonly property string terminal: _s("terminal", "kitty")          // used for apps whose .desktop file says Terminal=true
    readonly property int launcherMaxResults: _i("launcherMaxResults", 40)
    readonly property int launcherVisibleRows: _i("launcherVisibleRows", 7)
    readonly property int launcherMaxRecent: _i("launcherMaxRecent", 8)
    // true  = launcher hangs from the bar (fused, concave corners), floats only over a fullscreen window
    // false = old behaviour, always a floating card
    readonly property bool launcherDocked: _b("launcherDocked", true)

    // ---- launcher tabs (Apps | Run | Prime | Walls) -----------------------------------------
    // Run tab: commands you type are remembered locally (a small file only you can read).
    // A command that starts with a space is never remembered. false = remember nothing.
    readonly property bool runHistory: _b("runHistory", true)
    readonly property int runHistoryMax: _i("runHistoryMax", 50)
    // Prime tab: the wrapper that sends an app to the NVIDIA GPU (package `nvidia-prime` on Arch).
    readonly property string primeCommand: _s("primeCommand", "prime-run")
    // Walls tab: every image under these folders, subfolders included. "~" means your home folder.
    readonly property var wallpaperDirs: _l("wallpaperDirs", ["~/Pictures/Wallpapers"])
    readonly property var wallpaperExtensions: _l("wallpaperExtensions", ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tga", "tiff"])
    // awww transition: none simple fade left right top bottom wipe wave grow center any outer random
    readonly property string wallpaperTransition: _s("wallpaperTransition", "random")
    readonly property real wallpaperTransitionDuration: _r("wallpaperTransitionDuration", 0)    // seconds; 0 = awww's own default (3)
    readonly property int wallpaperColumns: _i("wallpaperColumns", 3)
    readonly property int wallpaperVisibleRows: _i("wallpaperVisibleRows", 3)
    readonly property int wallpaperThumbDelay: _i("wallpaperThumbDelay", 90)            // ms a cell must stay on screen before its thumbnail is decoded
    readonly property bool wallpaperAnimatePreview: _b("wallpaperAnimatePreview", true)     // the big preview (Ctrl+E) plays animated GIFs

    // ---- quick settings ---------------------------------------------------------
    // true  = hangs from the bar like the launcher; floats over a fullscreen window
    readonly property bool quickSettingsDocked: _b("quickSettingsDocked", true)
    // Glass: 100 = the built-in solid look (bar solid, panels 95%). Lower = the bar and the panels become translucent so the
    // hyprglass plugin (kurenai-ctl enable-glass) shows through. Without that plugin a low value only looks see-through.
    readonly property int glassOpacity: _i("glassOpacity", 100)        // clamped to 40..100 where it is used (Glass.qml)
    readonly property int qsMaxListRows: _i("qsMaxListRows", 6)              // Wi-Fi / Bluetooth / audio device lists scroll beyond this
    // Brightness uses `brightnessctl` (class "backlight"). Leave empty for the first backlight device;
    // set a name from `brightnessctl -l` to pin one (useful on hybrid-GPU laptops with two).
    readonly property string brightnessDevice: _s("brightnessDevice", "")
    // Brightness curve. MUST match your brightness keybinds, otherwise the slider/OSD and the keys
    // disagree about "50%". Your hyprland.lua uses `brightnessctl -e4 -n2`, so: 4 and 2.
    // (0 = plain linear percent, no -e/-n flags.)
    readonly property int brightnessExponent: _i("brightnessExponent", 4)
    readonly property int brightnessMin: _i("brightnessMin", 2)
    readonly property int nightLightTemp: _i("nightLightTemp", 4000)          // Kelvin, used with hyprsunset
    // Optional settings apps; the first one that is installed is used, none installed = no shortcut shown.
    readonly property var audioTools: _l("audioTools", ["pwvucontrol", "pavucontrol"])
    readonly property var networkTools: _l("networkTools", ["nm-connection-editor"])
    readonly property var bluetoothTools: _l("bluetoothTools", ["blueman-manager", "overskride"])

    // ---- popovers (media, calendar, power menu) -----------------------------------
    readonly property bool popoverDocked: _b("popoverDocked", true)          // hang from the bar; floats over a fullscreen window

    // ---- media --------------------------------------------------------------
    readonly property int mediaBarChars: _i("mediaBarChars", 28)             // "Title - Artist" is cut to this many characters in the bar

    // ---- calendar -----------------------------------------------------------
    readonly property int firstDayOfWeek: _i("firstDayOfWeek", -1)            // -1 = your locale; 0 = Sunday, 1 = Monday, ...

    // ---- power menu ------------------------------------------------------------
    // First installed one is used for "Lock". None installed = no Lock entry (never assumed).
    readonly property var lockTools: _l("lockTools", ["hyprlock", "swaylock", "gtklock", "waylock"])   // fallback only
    // With the KURENAI lock screen running (kurenai-lock), "Lock" uses it, and "Suspend" locks first.
    readonly property bool lockBeforeSuspend: _b("lockBeforeSuspend", true)

    // ---- keyboard shortcuts page (ShortcutsPanel / Keybinds) ----------------------------
    // The Hyprland Lua config to read. Empty = $XDG_CONFIG_HOME/hypr/hyprland.lua (usually ~/.config/hypr/hyprland.lua).
    // Every file it pulls in with require()/dofile() is followed automatically.
    readonly property string hyprMainFile: _s("hyprMainFile", "")
    readonly property int shortcutsVisibleRows: _i("shortcutsVisibleRows", 12)      // rows visible before the list scrolls

    // ---- on-screen display ---------------------------------------------------------
    readonly property int osdTimeout: _i("osdTimeout", 1400)              // ms
    readonly property bool osdVolume: _b("osdVolume", true)
    readonly property bool osdMic: _b("osdMic", true)
    readonly property bool osdBrightness: _b("osdBrightness", true)          // needs the one-line bind change, see `kurenai-ctl media-binds`
    readonly property bool osdMediaPlayPause: _b("osdMediaPlayPause", true)
    readonly property bool osdMediaTrack: _b("osdMediaTrack", true)          // shows on every track change, incl. automatic ones

    // ---- clipboard history (needs cliphist + wl-clipboard) -------------------------------
    readonly property bool clipboardEnabled: _b("clipboardEnabled", true)       // false = record nothing at all
    readonly property int clipboardRetentionDays: _i("clipboardRetentionDays", 30)    // older history is deleted automatically; PINNED items are kept
    readonly property int clipboardMaxItems: _i("clipboardMaxItems", 500)
    readonly property int clipboardMaxStoreMB: _i("clipboardMaxStoreMB", 10)       // biggest single item recorded (cliphist's own default is 5 MB: too small for screenshots)

    // ---- system monitor ---------------------------------------------------------------------
    readonly property int sysmonInterval: _i("sysmonInterval", 2000)          // ms; it only samples while its panel is open

    // ---- notifications -----------------------------------------------------
    readonly property int maxPopups: _i("maxPopups", 4)
    readonly property int popupTimeoutLow: _i("popupTimeoutLow", 4000)         // ms
    readonly property int popupTimeoutNormal: _i("popupTimeoutNormal", 7000)
    // critical notifications never time out: they stay until you dismiss them
}
