pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System monitor data. It samples ONLY while the monitor panel is open (the Timer is bound to UiState.sysmonOpen),
// so it costs nothing the rest of the time. One snapshot = one run of the read-only helper `kurenai-sysmon`.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/kurenai-sysmon"

    property bool ok: false
    property real cpu: -1                // percent; -1 until two samples exist
    property real memTotal: 0            // kB
    property real memAvail: 0
    property real swapTotal: 0
    property real swapFree: 0
    property real temp: -1               // degrees C; -1 = no CPU sensor
    property var load: [0, 0, 0]
    property var disks: []               // { mount, size, used } in bytes

    readonly property real memUsed: memTotal - memAvail
    readonly property real swapUsed: swapTotal - swapFree

    property var _prev: null

    function gib(bytes) { return (bytes / 1073741824).toFixed(bytes < 10737418240 ? 1 : 0) + " GiB"; }
    function gibKb(kb)  { return gib(kb * 1024); }

    function sample() { if (!proc.running) proc.running = true; }

    function parse(text) {
        const lines = text.split("\n");
        const disks = [];
        let sawTemp = false;
        for (let i = 0; i < lines.length; i++) {
            const eq = lines[i].indexOf("=");
            if (eq < 0) continue;
            const k = lines[i].substring(0, eq);
            const v = lines[i].substring(eq + 1).trim();
            if (k === "cpu") {
                const n = v.split(" ").map(x => parseInt(x) || 0);       // user nice system idle iowait irq softirq steal
                const total = n.reduce((a, b) => a + b, 0);
                const idle = n[3] + n[4];
                if (_prev) {
                    const dt = total - _prev.total;
                    const di = idle - _prev.idle;
                    if (dt > 0) cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100));
                }
                _prev = { total: total, idle: idle };
            } else if (k === "memtotal") memTotal = parseInt(v) || 0;
            else if (k === "memavailable") memAvail = parseInt(v) || 0;
            else if (k === "swaptotal") swapTotal = parseInt(v) || 0;
            else if (k === "swapfree") swapFree = parseInt(v) || 0;
            else if (k === "load") load = v.split(" ");
            else if (k === "temp") { temp = parseInt(v); sawTemp = true; }
            else if (k === "disk") {
                const f = v.split(" ");
                if (f.length >= 3) disks.push({ mount: f[0], size: parseFloat(f[1]) || 0, used: parseFloat(f[2]) || 0 });
            }
        }
        if (!sawTemp) temp = -1;
        root.disks = disks;
        root.ok = true;
    }

    Process {
        id: proc
        command: [root.helper]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: Config.sysmonInterval
        repeat: true
        running: UiState.sysmonOpen
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // forget the previous sample when the panel closes, so the next opening never shows a stale average
    Connections {
        target: UiState
        function onSysmonOpenChanged() { if (!UiState.sysmonOpen) { root._prev = null; root.cpu = -1; } }
    }
}
