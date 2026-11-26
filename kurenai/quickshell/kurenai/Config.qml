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
    readonly property int nightLightTemp: 4000          // Kelvin, used with hyprsunset
    // Optional settings apps; the first one that is installed is used, none installed = no shortcut shown.
    readonly property var audioTools: ["pwvucontrol", "pavucontrol"]
    readonly property var networkTools: ["nm-connection-editor"]
    readonly property var bluetoothTools: ["blueman-manager", "overskride"]

    // ---- notifications -----------------------------------------------------
    readonly property int maxPopups: 4
    readonly property int popupTimeoutLow: 4000         // ms
    readonly property int popupTimeoutNormal: 7000
    // critical notifications never time out: they stay until you dismiss them
}
