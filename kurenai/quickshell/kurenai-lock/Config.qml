pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// KURENAI lock screen settings. Colours/fonts come from Theme.qml (a copy of the main shell's theme:
// `kurenai-ctl lock-sync-theme` refreshes it after you edit the original).
//
// The values below are the DEFAULTS. The look and attempt-limit settings can be changed with `kurenai-conf set lock.KEY VALUE`
// (or in the KURENAI settings window); they are read from ~/.config/kurenai/settings.json, clamped to safe ranges, and any
// problem leaves the default. The AUTHENTICATION settings (pam*) are deliberately NOT read from that file: a lock screen's
// PAM service is only ever changed here, by hand, on purpose. Test changes first with: kurenai-ctl lock-preview
Singleton {
    id: root

    property var _o: ({})
    readonly property string settingsFile:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/kurenai/settings.json"
    FileView {
        id: overrides
        path: root.settingsFile
        printErrors: false
        onLoaded: {
            try { const d = JSON.parse(overrides.text()); root._o = (d && typeof d === "object" && !Array.isArray(d)) ? d : ({}); }
            catch (e) { root._o = ({}); }
        }
        onLoadFailed: error => root._o = ({})
    }
    function _b(k, d) { const v = _o["lock." + k]; return typeof v === "boolean" ? v : d; }
    function _n(k, d, lo, hi) { const v = _o["lock." + k]; return (typeof v === "number" && isFinite(v)) ? Math.max(lo, Math.min(hi, v)) : d; }
    function _s(k, d) { const v = _o["lock." + k]; return (typeof v === "string" && v.length <= 200) ? v : d; }

    // ---- authentication ------------------------------------------------------------
    // "" = the bundled ./pam/ files (user-owned, works without root).
    // For a root-owned service instead (see `kurenai-ctl lock-harden`): "/etc/pam.d" and "kurenai-lock".
    readonly property string pamDirectory: ""
    readonly property string pamPassword: "password.conf"
    readonly property string pamFingerprint: "fingerprint.conf"
    readonly property bool fingerprint: _b("fingerprint", true)            // needs fprintd + an enrolled finger

    readonly property int maxAttempts: Math.round(_n("maxAttempts", 5, 1, 20))                // wrong passwords in a row before a short cooldown
    readonly property int cooldownSeconds: Math.round(_n("cooldownSeconds", 10, 1, 600))

    // ---- look ----------------------------------------------------------------------------
    readonly property bool useAwww: _b("useAwww", true)                // use the wallpaper `awww query` reports for each monitor
    readonly property string wallpaper: _s("wallpaper", "")              // fallback image path if awww is unavailable ("" = generated pattern)
    readonly property real dim: _n("dim", 0.5, 0, 1)                     // how much the wallpaper is darkened (0..1)
    readonly property int idleHideSeconds: Math.round(_n("idleHideSeconds", 12, 2, 120))           // the input field fades away after this long untouched
    readonly property string deviceLabel: _s("deviceLabel", "ThinkPad P53")
    readonly property bool showNotificationCount: _b("showNotificationCount", true)  // a COUNT only, never the contents
}
