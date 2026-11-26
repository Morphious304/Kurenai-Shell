pragma Singleton
import QtQuick

// Surface colours for the optional compositor glass (hyprglass plugin, `kurenai-ctl enable-glass`).
// Config.glassOpacity = 100 (the default): these are EXACTLY the built-in Theme colours, nothing changes.
// Lower: only the ALPHA of the bar and panel colours changes (never the RGB), so the glass behind them shows through.
// Kept out of Theme.qml on purpose: Theme.qml is shared verbatim with the lock screen and the settings window.
QtObject {
    readonly property int pct: Math.max(40, Math.min(100, Config.glassOpacity))
    readonly property bool on: pct < 100
    function withOpacity(c, p) { const q = Qt.color(String(c)); return Qt.rgba(q.r, q.g, q.b, p / 100); }

    readonly property color barBg:   on ? withOpacity(Theme.bg, pct)      : Theme.bg       // bar and the shapes fused to it
    readonly property color panelBg: on ? withOpacity(Theme.panelBg, pct) : Theme.panelBg  // panels, popups, notification cards
}
