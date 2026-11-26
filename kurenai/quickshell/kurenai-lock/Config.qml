pragma Singleton
import QtQuick
import Quickshell

// KURENAI lock screen settings. Colours/fonts come from Theme.qml (a copy of the main shell's theme:
// `kurenai-ctl lock-sync-theme` refreshes it after you edit the original).
Singleton {
    // ---- authentication ------------------------------------------------------------
    // "" = the bundled ./pam/ files (user-owned, works without root).
    // For a root-owned service instead (see `kurenai-ctl lock-harden`): "/etc/pam.d" and "kurenai-lock".
    readonly property string pamDirectory: ""
    readonly property string pamPassword: "password.conf"
    readonly property string pamFingerprint: "fingerprint.conf"
    readonly property bool fingerprint: true            // needs fprintd + an enrolled finger

    readonly property int maxAttempts: 5                // wrong passwords in a row before a short cooldown
    readonly property int cooldownSeconds: 10

    // ---- look ----------------------------------------------------------------------------
    readonly property bool useAwww: true                // use the wallpaper `awww query` reports for each monitor
    readonly property string wallpaper: ""              // fallback image path if awww is unavailable ("" = generated pattern)
    readonly property real dim: 0.5                     // how much the wallpaper is darkened (0..1)
    readonly property int idleHideSeconds: 12           // the input field fades away after this long untouched
    readonly property string deviceLabel: "ThinkPad P53"
    readonly property bool showNotificationCount: true  // a COUNT only, never the contents
}
