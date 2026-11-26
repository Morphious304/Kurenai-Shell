pragma Singleton
import QtQuick
import Quickshell

// KURENAI behaviour settings (things you might want to change that are not visual design).
// Design tokens (colours, sizes, fonts) live in Theme.qml.
Singleton {
    // ---- launcher ----------------------------------------------------------
    readonly property string terminal: "kitty"          // used for apps whose .desktop file says Terminal=true
    readonly property int launcherMaxResults: 40
    readonly property int launcherVisibleRows: 7
    readonly property int launcherMaxRecent: 8
    // true  = launcher hangs from the bar (fused, concave corners), floats only over a fullscreen window
    // false = old behaviour, always a floating card
    readonly property bool launcherDocked: true

    // ---- quick settings ---------------------------------------------------------
    // true  = hangs from the bar like the launcher; floats over a fullscreen window
    readonly property bool quickSettingsDocked: true
    readonly property int qsMaxListRows: 6              // Wi-Fi / Bluetooth / audio device lists scroll beyond this
    // Brightness uses `brightnessctl` (class "backlight"). Leave empty for the first backlight device;
    // set a name from `brightnessctl -l` to pin one (useful on hybrid-GPU laptops with two).
    readonly property string brightnessDevice: ""
    // Brightness curve. MUST match your brightness keybinds, otherwise the slider/OSD and the keys
    // disagree about "50%". Your hyprland.lua uses `brightnessctl -e4 -n2`, so: 4 and 2.
    // (0 = plain linear percent, no -e/-n flags.)
    readonly property int brightnessExponent: 4
    readonly property int brightnessMin: 2
    readonly property int nightLightTemp: 4000          // Kelvin, used with hyprsunset
    // Optional settings apps; the first one that is installed is used, none installed = no shortcut shown.
    readonly property var audioTools: ["pwvucontrol", "pavucontrol"]
    readonly property var networkTools: ["nm-connection-editor"]
    readonly property var bluetoothTools: ["blueman-manager", "overskride"]

    // ---- popovers (media, calendar, power menu) -----------------------------------
    readonly property bool popoverDocked: true          // hang from the bar; floats over a fullscreen window

    // ---- media --------------------------------------------------------------
    readonly property int mediaBarChars: 28             // "Title - Artist" is cut to this many characters in the bar

    // ---- calendar -----------------------------------------------------------
    readonly property int firstDayOfWeek: -1            // -1 = your locale; 0 = Sunday, 1 = Monday, ...

    // ---- power menu ------------------------------------------------------------
    // First installed one is used for "Lock". None installed = no Lock entry (never assumed).
    readonly property var lockTools: ["hyprlock", "swaylock", "gtklock", "waylock"]   // fallback only
    // With the KURENAI lock screen running (kurenai-lock), "Lock" uses it, and "Suspend" locks first.
    readonly property bool lockBeforeSuspend: true

    // ---- keyboard shortcuts page (ShortcutsPanel / Keybinds) ----------------------------
    // The Hyprland Lua config to read. Empty = $XDG_CONFIG_HOME/hypr/hyprland.lua (usually ~/.config/hypr/hyprland.lua).
    // Every file it pulls in with require()/dofile() is followed automatically.
    readonly property string hyprMainFile: ""
    readonly property int shortcutsVisibleRows: 12      // rows visible before the list scrolls

    // ---- on-screen display ---------------------------------------------------------
    readonly property int osdTimeout: 1400              // ms
    readonly property bool osdVolume: true
    readonly property bool osdMic: true
    readonly property bool osdBrightness: true          // needs the one-line bind change, see `kurenai-ctl media-binds`
    readonly property bool osdMediaPlayPause: true
    readonly property bool osdMediaTrack: true          // shows on every track change, incl. automatic ones

    // ---- clipboard history (needs cliphist + wl-clipboard) -------------------------------
    readonly property bool clipboardEnabled: true       // false = record nothing at all
    readonly property int clipboardRetentionDays: 30    // older history is deleted automatically; PINNED items are kept
    readonly property int clipboardMaxItems: 500
    readonly property int clipboardMaxStoreMB: 10       // biggest single item recorded (cliphist's own default is 5 MB: too small for screenshots)

    // ---- system monitor ---------------------------------------------------------------------
    readonly property int sysmonInterval: 2000          // ms; it only samples while its panel is open

    // ---- notifications -----------------------------------------------------
    readonly property int maxPopups: 4
    readonly property int popupTimeoutLow: 4000         // ms
    readonly property int popupTimeoutNormal: 7000
    // critical notifications never time out: they stay until you dismiss them
}
