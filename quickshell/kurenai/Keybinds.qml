pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "BindParser.js" as BP

// The one list of keyboard shortcuts (read by ShortcutsPanel).
//
// Where it comes from:
//   1. FILES: hyprland.lua and every file it pulls in with require()/dofile(), read by BindParser.js,
//      a side-effect-free reader (it never runs anything). Gives chord + what it does + file:line.
//   2. HYPRLAND: `hyprctl binds` (read-only). Confirms which of those are really active, and adds any bind
//      Hyprland has that the file reader could not explain, so nothing is silently missing.
//
// How it stays current (no restart, no manual rescan):
//   * every file in the chain is watched (FileView.watchChanges)
//   * while the page is OPEN the files are also re-read every 2 s (cheap; covers editors that save by
//     replacing the file, which a watcher can miss). Nothing is re-analysed unless the text changed.
//   * Hyprland's `configreloaded` event and opening the page both refresh the "active in Hyprland" check
//   * adding/removing a require() line is followed automatically (new files are picked up, dropped ones ignored)
Singleton {
    id: root

    // ------------------------------------------------------------------ results
    property var entries: []              // shortcuts (config + Hyprland-only), see BindParser.js
    property var fileList: []             // [{path, status, via, binds}] the files that make up the config
    property var warnings: []             // [{file, line, msg}] things the reader could not follow
    property var notes: []                // [{file, line, msg}] informational
    property string state: "loading"      // loading | ok | nomain | error
    property string errorText: ""
    property string runtimeState: "unknown"   // unknown | ok | unavailable  (the `hyprctl binds` check)
    property int runtimeOnly: 0           // how many entries only Hyprland knows about
    property string updatedAt: ""

    // ------------------------------------------------------------------ where to read
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string mainFile: Config.hyprMainFile !== "" ? Config.hyprMainFile : (configHome + "/hypr/hyprland.lua")
    readonly property string configDir: mainFile.replace(/\/[^\/]*$/, "")

    // ------------------------------------------------------------------ internals
    property var _files: ({})             // path -> text | null (unreadable); missing key = not asked yet
    property var _globs: ({})             // wildcard pattern -> [paths]
    property var _runtime: null           // parsed `hyprctl binds`, or null
    property var _paths: [mainFile]       // files we hold a watcher for (only ever grows during a session)
    property var _analysis: null

    function _env() {
        const names = ["HOME", "USER", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "TERMINAL", "BROWSER", "EDITOR", "XDG_SESSION_TYPE"];
        const out = {};
        for (let i = 0; i < names.length; i++) {
            const v = Quickshell.env(names[i]);
            if (v !== null && v !== undefined && v !== "") out[names[i]] = v;
        }
        return out;
    }

    function _addPaths(list) {
        let grew = false;
        const next = _paths.slice();
        for (let i = 0; i < list.length; i++) {
            if (next.indexOf(list[i]) < 0) { next.push(list[i]); grew = true; }
        }
        if (grew) _paths = next;
    }

    function _onFile(path, text) {
        if (_files[path] === text) return;              // same text (or still unreadable): nothing to redo
        _files[path] = text;
        analyseTimer.restart();
        hyprctlSoon.restart();                           // Hyprland usually auto-reloaded by now: re-check what is active
    }

    function _analyse() {
        let res = null;
        try {
            res = BP.analyze({
                mainFile: mainFile, configDir: configDir,
                files: _files, globs: _globs, env: _env()
            });
        } catch (e) {
            console.warn("[kurenai] shortcuts reader failed:", e);
            errorText = String(e);
            state = "error";
            return;
        }
        _analysis = res;

        // files / wildcard folders it asked for (one more round once they arrive)
        _addPaths(res.needFiles);
        const wants = [];
        for (let i = 0; i < res.needGlobs.length; i++) {
            if (!(res.needGlobs[i] in _globs) && globQueue.indexOf(res.needGlobs[i]) < 0) wants.push(res.needGlobs[i]);
        }
        if (wants.length) { globQueue = globQueue.concat(wants); runGlobs(); }

        _publish();
    }

    function _publish() {
        const res = _analysis;
        if (res === null) return;
        const rec = BP.reconcile(res.entries, _runtime);
        entries = rec.entries;
        runtimeOnly = rec.runtimeOnly;
        fileList = res.files;
        warnings = res.warnings;
        notes = res.notes;
        errorText = "";
        state = res.mainState === "ok" ? "ok" : (res.mainState === "missing" ? "nomain" : "loading");
        updatedAt = Qt.formatTime(new Date(), "HH:mm:ss");
    }

    // ------------------------------------------------------------------ public
    // Re-read everything now. Cheap; called when the page opens.
    function refresh() {
        reloadFiles();
        askHyprland();
        const known = Object.keys(_globs);
        if (known.length) { globQueue = globQueue.concat(known.filter(p => globQueue.indexOf(p) < 0)); runGlobs(); }
    }

    function reloadFiles() {
        for (let i = 0; i < viewers.count; i++) {
            const v = viewers.objectAt(i);
            if (v) v.reload();
        }
    }

    function statusText() {
        return BP.statusText(entries, fileList, warnings, notes, runtimeState)
               + (state === "nomain" ? "\n  main config not found: " + mainFile : "")
               + (state === "error" ? "\n  reader error: " + errorText : "");
    }

    // ------------------------------------------------------------------ the files (one watcher each)
    Instantiator {
        id: viewers
        model: root._paths
        delegate: FileView {
            id: fv
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: fv.reload()
            onLoaded: root._onFile(fv.path, fv.text())
            onLoadFailed: error => root._onFile(fv.path, null)
        }
    }

    Timer { id: analyseTimer; interval: 120; onTriggered: root._analyse() }

    // while the page is open: re-read the files every 2 s (a no-op unless something changed)
    Timer {
        interval: 2000
        repeat: true
        running: UiState.shortcutsOpen
        onTriggered: root.reloadFiles()
    }

    // ------------------------------------------------------------------ wildcard require("./dir/*")
    property var globQueue: []
    property var _globBusy: []

    function runGlobs() {
        if (globProc.running || globQueue.length === 0) return;
        _globBusy = globQueue;
        globQueue = [];
        // Patterns come from the user's own config and are only ever PATH-expanded by the shell (no command
        // substitution: they are passed as arguments and expanded unquoted, nothing is evaluated).
        globProc.command = ["bash", "-c",
            "shopt -s nullglob; IFS=; for p in \"$@\"; do for f in $p $p.lua $p/init.lua; do " +
            "case \"$f\" in *.lua) [ -f \"$f\" ] && printf '%s\\t%s\\n' \"$p\" \"$f\";; esac; done; done",
            "bash"].concat(_globBusy);
        globProc.running = true;
    }

    Process {
        id: globProc
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (let i = 0; i < root._globBusy.length; i++) found[root._globBusy[i]] = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const kv = lines[i].split("\t");
                    if (kv.length === 2 && found[kv[0]] !== undefined && found[kv[0]].indexOf(kv[1]) < 0) found[kv[0]].push(kv[1]);
                }
                let changed = false;
                for (const p in found) {
                    found[p].sort();
                    if (JSON.stringify(root._globs[p] || null) !== JSON.stringify(found[p])) { root._globs[p] = found[p]; changed = true; }
                    root._addPaths(found[p]);
                }
                if (changed) analyseTimer.restart();
            }
        }
        onExited: (code, status) => { if (root.globQueue.length) root.runGlobs(); }
    }

    // ------------------------------------------------------------------ what Hyprland itself has bound
    property bool _askAgain: false

    function askHyprland() {
        if (hyprctlProc.running) _askAgain = true;
        else hyprctlProc.running = true;
    }

    Timer { id: hyprctlSoon; interval: 700; onTriggered: root.askHyprland() }

    Process {
        id: hyprctlProc
        // exit 127 = no hyprctl on PATH. Read-only: `hyprctl binds` changes nothing.
        command: ["sh", "-c", "command -v hyprctl >/dev/null 2>&1 || exit 127; exec hyprctl binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = BP.parseHyprctlBinds(text);
                root._runtime = parsed.length > 0 ? parsed : null;
                root.runtimeState = parsed.length > 0 ? "ok" : "unavailable";
                root._publish();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) { root._runtime = null; root.runtimeState = "unavailable"; root._publish(); }
            if (root._askAgain) { root._askAgain = false; hyprctlProc.running = true; }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") hyprctlSoon.restart();
        }
    }

    Component.onCompleted: askHyprland()
}
