pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history state. The engine is the helper script `kurenai-clip` (a thin layer over cliphist);
// this file only starts/stops the recording and shows what the helper reports.
//
// Privacy, in short (the README has the full list):
//   * Everything stays on this machine. Clipboard contents are NEVER written to a log: nothing in this file
//     calls console.log with an entry.
//   * Recording runs ONLY while `recording` is true. Pausing stops the watchers and the helper also drops data
//     if a stale watcher is still around. Config.clipboardEnabled = false means nothing is ever recorded.
//   * History older than Config.clipboardRetentionDays is deleted (at start, every 6 h, and when the panel opens).
//     Pinned items are copies kept separately and are never auto-deleted.
//   * Nothing else in the shell reads the clipboard.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: home + "/.local/bin/kurenai-clip"
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kurenai-clip"
    readonly property string pinDir: (Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")) + "/kurenai/clipboard/pins"

    property bool toolsOk: false          // cliphist, wl-copy, wl-paste and the helper are all present
    property bool paused: false
    property var entries: []              // history, newest first: { id, kind, mime, epoch, preview }
    property var pins: []                 // pinned items:           { id (pin number), kind, mime, epoch, preview }
    readonly property bool enabled: Config.clipboardEnabled
    property bool stateKnown: false       // the saved "paused" flag has been read (recording never starts before this)
    readonly property bool ready: enabled && toolsOk
    readonly property bool recording: ready && stateKnown && !paused

    // ---------------------------------------------------------------- lists
    function parse(text, isPin) {
        const out = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue;
            const f = lines[i].split("\t");
            if (f.length < 5) continue;
            out.push({ id: f[0], kind: f[1], mime: f[2], epoch: parseInt(f[3]) || 0, preview: f.slice(4).join(" "), pin: isPin });
        }
        return out;
    }

    function refresh() {
        if (!ready) return;
        if (!listProc.running) listProc.running = true;
        if (!pinsProc.running) pinsProc.running = true;
    }
    function refreshSoon() { refreshTimer.restart(); }
    Timer { id: refreshTimer; interval: 250; onTriggered: root.refresh() }

    Process {
        id: listProc
        command: [root.helper, "list"]
        stdout: StdioCollector { onStreamFinished: root.entries = root.parse(text, false) }
    }
    Process {
        id: pinsProc
        command: [root.helper, "pins"]
        stdout: StdioCollector { onStreamFinished: root.pins = root.parse(text, true) }
    }

    // ---------------------------------------------------------------- actions (ids come from the helper's own list)
    function run(args) { Quickshell.execDetached([helper].concat(args)); refreshSoon(); }

    function copyEntry(e)   { run([e.pin ? "copy-pin" : "copy", String(e.id)]); }
    function pinEntry(e)    { run(["pin", String(e.id)]); }
    function unpinEntry(e)  { run(["unpin", String(e.id)]); }
    function deleteEntry(e) { if (e.pin) unpinEntry(e); else run(["delete", String(e.id)]); }
    function wipeHistory()  { run(["wipe"]); }          // pinned items are kept
    function unpinAll()     { run(["unpin-all"]); }

    function purge() {
        if (!ready) return;
        Quickshell.execDetached([helper, "purge", String(Config.clipboardRetentionDays)]);
        refreshSoon();
    }
    Timer { interval: 6 * 3600 * 1000; repeat: true; running: root.ready; onTriggered: root.purge() }

    function ago(epoch) {
        if (!epoch) return "";
        const m = Math.floor((Date.now() / 1000 - epoch) / 60);
        if (m < 1) return "just now";
        if (m < 60) return m + " min ago";
        const h = Math.floor(m / 60);
        if (h < 48) return h + " h ago";
        return Math.floor(h / 24) + " d ago";
    }

    // ---------------------------------------------------------------- image thumbnails
    // History images are decoded one at a time into $XDG_RUNTIME_DIR (private, in memory), only when a row is
    // actually shown, and removed again when the panel closes.
    property var thumbReady: ({})
    property var thumbQueue: []
    property string thumbCurrent: ""

    function thumbPath(id) { return runDir + "/h" + id + ".img"; }
    function requestThumb(id) {
        if (thumbReady[id] === true || thumbQueue.indexOf(id) >= 0 || thumbCurrent === id) return;
        thumbQueue = thumbQueue.concat([id]);
        pumpThumbs();
    }
    function pumpThumbs() {
        if (thumbProc.running || thumbQueue.length === 0) return;
        thumbCurrent = thumbQueue[0];
        thumbQueue = thumbQueue.slice(1);
        thumbProc.command = [helper, "thumb", String(thumbCurrent)];
        thumbProc.running = true;
    }
    Process {
        id: thumbProc
        onExited: (code, status) => {
            if (code === 0) {
                const m = Object.assign({}, root.thumbReady);
                m[root.thumbCurrent] = true;
                root.thumbReady = m;
            }
            root.thumbCurrent = "";
            root.pumpThumbs();
        }
    }
    function clearThumbs() {
        thumbReady = ({});
        thumbQueue = [];
        Quickshell.execDetached([helper, "thumbs-clean"]);
    }

    // ---------------------------------------------------------------- recording (two watchers: text and images)
    function syncWatchers() {
        const want = recording;
        if (textWatch.running !== want) textWatch.running = want;
        if (imageWatch.running !== want) imageWatch.running = want;
    }
    onRecordingChanged: syncWatchers()
    Timer { id: watchRestart; interval: 3000; onTriggered: root.syncWatchers() }

    readonly property var watchEnv: ["env", "KURENAI_CLIP_MAX_ITEMS=" + Config.clipboardMaxItems,
                                     "KURENAI_CLIP_MAX_STORE=" + Config.clipboardMaxStoreMB + "MB"]
    Process {
        id: textWatch
        command: root.watchEnv.concat(["wl-paste", "--type", "text", "--watch", root.helper, "store"])
        onExited: (code, status) => watchRestart.restart()
    }
    Process {
        id: imageWatch
        command: root.watchEnv.concat(["wl-paste", "--type", "image", "--watch", root.helper, "store"])
        onExited: (code, status) => watchRestart.restart()
    }

    function setPaused(p) {
        run([p ? "pause" : "resume"]);
        paused = p;                       // recording follows: the watchers stop / start
    }

    // ---------------------------------------------------------------- start-up
    // Order matters: (1) check the tools, (2) stop recorders left behind by an earlier, crashed shell (ours only),
    // (3) read the saved paused flag, (4) only THEN may recording start. So a paused history is never recorded,
    // and a fresh recorder is never killed by the clean-up.
    Process {
        id: probe
        command: ["sh", "-c", 'command -v cliphist >/dev/null && command -v wl-copy >/dev/null && command -v wl-paste >/dev/null && test -x "$1"',
                  "sh", root.helper]
        onExited: (code, status) => {
            if (code === 0) cleanStrays.running = true;
            else root.toolsOk = false;
        }
    }
    Process {
        id: cleanStrays
        command: ["pkill", "-f", "wl-paste .*kurenai-clip store"]        // exit 1 = none found: fine
        onExited: (code, status) => { root.toolsOk = true; pausedProc.running = true; }
    }
    Process {
        id: pausedProc
        command: [root.helper, "paused"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.paused = text.trim() === "yes";
                root.stateKnown = true;          // this is what lets `recording` become true
                root.purge();
                root.refresh();
            }
        }
    }

    Component.onCompleted: { if (enabled) probe.running = true; }
}
