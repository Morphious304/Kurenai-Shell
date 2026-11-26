pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper colours: the shell's side of `kurenai-ctl theme ...` (matugen does the colour maths there).
// This file only
//   * runs kurenai-ctl (one job at a time; a newer wallpaper replaces one that is still waiting),
//   * mirrors ~/.local/share/kurenai/theme.conf so Quick Settings can show the state,
//   * asks Theme.qml to re-read the palette when a job is done (Theme also watches the file itself).
// If matugen is not installed nothing here does anything and `available` stays false.
Singleton {
    id: root

    // ---- state the UI shows ----------------------------------------------------------------------------
    property bool available: false       // matugen found on PATH
    property bool enabled: false         // theme.conf: enabled=1
    property string type: "tonal-spot"   // matugen scheme type
    property string accent: "wallpaper"  // "wallpaper" | "vermilion"
    property bool busy: false
    property string error: ""            // last failure, one line; cleared by the next job

    readonly property string stateDir: (Quickshell.env("XDG_DATA_HOME") || ((Quickshell.env("HOME") || "") + "/.local/share")) + "/kurenai"

    // ---- conf mirror -----------------------------------------------------------------------------------
    function parseConf(text) {
        const o = {};
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = /^([a-z]+)=(.*)$/.exec(lines[i]);
            if (m) o[m[1]] = m[2].trim();
        }
        return o;
    }
    function applyConf(text) {
        const o = parseConf(text);
        enabled = o.enabled === "1";
        type = o.type || "tonal-spot";
        accent = o.accent === "vermilion" ? "vermilion" : "wallpaper";
    }
    function refresh() { conf.reload(); }

    FileView {
        id: conf
        path: root.stateDir + "/theme.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: conf.reload()
        onLoaded: root.applyConf(conf.text())
        onLoadFailed: error => root.applyConf("")      // no file yet = defaults (off)
    }

    // ---- is matugen there? -----------------------------------------------------------------------------
    Process {
        id: probe
        command: ["sh", "-c", "command -v matugen >/dev/null 2>&1"]
        onExited: (code, status) => root.available = (code === 0)
    }

    // ---- one job at a time -----------------------------------------------------------------------------
    property var queue: []               // [{ key, args }]
    readonly property var jobShell: ["sh", "-c", 'k=$(command -v kurenai-ctl || echo "$HOME/.local/bin/kurenai-ctl"); exec "$k" "$@"', "sh"]

    function enqueue(key, args) {
        const q = queue.filter(j => j.key !== key);     // same kind of job already waiting: the newest wins
        q.push({ key: key, args: args });
        queue = q;
        pump();
    }
    function pump() {
        if (job.running || queue.length === 0) return;
        const next = queue[0];
        queue = queue.slice(1);
        busy = true;
        error = "";
        job.command = jobShell.concat(next.args);
        job.running = true;
    }

    Process {
        id: job
        stderr: StdioCollector { id: jobErr }
        stdout: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                const lines = String(jobErr.text || "").trim().split("\n");
                root.error = lines[lines.length - 1] || "kurenai-ctl exited with an error";
            }
            root.busy = false;
            root.refresh();
            Theme.reloadPalette();
            root.pump();
        }
    }

    // ---- actions ----------------------------------------------------------------------------------------
    function setEnabled(on) { if (available) enqueue("toggle", ["theme", on ? "on" : "off"]); }
    function toggle() { setEnabled(!enabled); }
    function nextType() { if (available) enqueue("type", ["theme", "type", "next"]); }
    function setAccent(a) { if (available) enqueue("accent", ["theme", "accent", a === "vermilion" ? "vermilion" : "wallpaper"]); }
    function resync() { if (available && enabled) enqueue("sync", ["theme-sync", "--force", "--auto"]); }

    // called by Walls.qml after a wallpaper was set: recolour from that very file (does nothing when the feature is off)
    function applyImage(path) {
        if (!available || !enabled || !path) return;
        enqueue("apply", ["theme-apply", "--auto", path]);
    }

    // once at shell start: catch up if the wallpaper changed while the shell was not running
    function start() { probe.running = true; startTimer.restart(); }
    Timer {
        id: startTimer
        interval: 3000
        onTriggered: if (root.available && root.enabled) root.enqueue("sync", ["theme-sync", "--auto"])
    }

    Component.onCompleted: { conf.reload(); probe.running = true; }
}
