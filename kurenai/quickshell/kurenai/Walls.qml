pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's Walls tab: finds your wallpapers and sets them with awww.
//   * scan   : one `find` over every folder in Config.wallpaperDirs, subfolders included (symlinks followed)
//   * set    : awww img -t <Config.wallpaperTransition> <file>     (default transition: random)
//   * current: awww query -j   (the same call the lock screen uses, so the lock background follows along)
// awww itself remembers the wallpaper across restarts (its cache in ~/.cache/awww), so nothing is saved here.
Singleton {
    id: root

    // ---- state the tab shows --------------------------------------------------------------------------------
    property var files: []              // { path, name, rel, gif }  sorted by folder, then name
    property bool scanning: false
    property string scanNote: ""        // why the list is empty, when it is
    property var currentPaths: []       // what awww reports right now (one per monitor)
    property bool awwwFound: true
    property string status: ""          // one short line after you apply something ("Applying ...", "Daemon not running ...")
    property bool statusIsError: false

    readonly property string home: Quickshell.env("HOME") || ""

    // the transitions awww documents; anything else in Config falls back to "random"
    readonly property var transitions: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"]
    readonly property string transition: transitions.indexOf(Config.wallpaperTransition) >= 0 ? Config.wallpaperTransition : "random"

    function expand(dir) {
        const d = String(dir || "").trim();
        if (d === "~") return home;
        if (d.startsWith("~/")) return home + d.slice(1);
        return d;
    }
    readonly property var dirs: {
        const out = [];
        const list = Config.wallpaperDirs || [];
        for (let i = 0; i < list.length; i++) {
            const d = expand(list[i]).replace(/\/+$/, "");
            if (d !== "" && out.indexOf(d) < 0) out.push(d);
        }
        return out;
    }

    // ---- scan -----------------------------------------------------------------------------------------------------
    function rescan() {
        if (scanProc.running || dirs.length === 0) {
            if (dirs.length === 0) { files = []; scanNote = "No wallpaper folder is set (Config.wallpaperDirs)."; }
            return;
        }
        scanning = true;
        scanNote = "";
        const args = ["find", "-L"].concat(dirs).concat(["-type", "f", "("]);
        const exts = Config.wallpaperExtensions || [];
        for (let i = 0; i < exts.length; i++) {
            if (i > 0) args.push("-o");
            args.push("-iname", "*." + exts[i]);
        }
        args.push(")", "-print");
        scanProc.command = args;
        scanProc.running = true;
    }

    function parse(text) {
        const lines = text.split("\n");
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            const path = lines[i];
            if (path === "") continue;
            let rel = path;
            for (let d = 0; d < dirs.length; d++) {
                if (path.startsWith(dirs[d] + "/")) { rel = path.slice(dirs[d].length + 1); break; }
            }
            const slash = rel.lastIndexOf("/");
            out.push({
                path: path,
                name: rel.slice(slash + 1),
                rel: rel,
                gif: /\.gif$/i.test(path)
            });
        }
        out.sort((a, b) => a.rel.toLowerCase().localeCompare(b.rel.toLowerCase()));
        return out;
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: root.files = root.parse(text)
        }
        stderr: StdioCollector {}      // `find` complains about missing folders; that is reported below, not logged
        onExited: (code, status) => {
            root.scanning = false;
            if (root.files.length === 0) {
                root.scanNote = "No images found in " + root.dirs.join(", ")
                    + (code !== 0 ? " (a folder may be missing or unreadable)." : ".");
            }
        }
    }

    // ---- filter ----------------------------------------------------------------------------------------------------
    // every word must appear in the path relative to its wallpaper folder (so folder names work too)
    function filter(query) {
        const terms = String(query || "").toLowerCase().split(/\s+/).filter(t => t !== "");
        if (terms.length === 0) return files;
        const out = [];
        for (let i = 0; i < files.length; i++) {
            const hay = files[i].rel.toLowerCase();
            let ok = true;
            for (let t = 0; t < terms.length; t++) if (hay.indexOf(terms[t]) < 0) { ok = false; break; }
            if (ok) out.push(files[i]);
        }
        return out;
    }

    function isCurrent(path) { return currentPaths.indexOf(path) >= 0; }

    // ---- what awww shows now ---------------------------------------------------------------------------------------
    function refreshCurrent() {
        if (!queryProc.running) queryProc.running = true;
    }
    Process {
        id: queryProc
        command: ["awww", "query", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const groups = Array.isArray(d) ? [d] : Object.keys(d).map(k => d[k]);
                    const found = [];
                    for (let g = 0; g < groups.length; g++) {
                        const list = Array.isArray(groups[g]) ? groups[g] : [];
                        for (let i = 0; i < list.length; i++) {
                            const o = list[i];
                            if (o && o.displaying && o.displaying.image && found.indexOf(o.displaying.image) < 0)
                                found.push(o.displaying.image);
                        }
                    }
                    root.currentPaths = found;
                } catch (e) {
                    root.currentPaths = [];
                }
            }
        }
        // exit code != 0 usually means the daemon is not running (or awww is not installed: see probe)
        onExited: (code, status) => {
            if (code !== 0 && root.status === "") {
                root.status = root.awwwFound ? "awww is installed but not answering: is awww-daemon running?" : "awww was not found.";
                root.statusIsError = true;
            }
        }
    }

    Process {
        id: awwwProbe
        command: ["sh", "-c", "command -v awww >/dev/null 2>&1"]
        onExited: (code, status) => {
            root.awwwFound = (code === 0);
            if (!root.awwwFound) {
                root.status = "awww was not found, so wallpapers cannot be set (package: awww).";
                root.statusIsError = true;
            }
        }
    }

    // ---- set -------------------------------------------------------------------------------------------------------
    property string applying: ""
    function apply(path) {
        if (!path || applyProc.running) return;
        if (!awwwFound) return;
        applying = path;
        status = /\.gif$/i.test(path) ? "Applying... (a big animated GIF is slow the first time; awww caches it)" : "Applying...";
        statusIsError = false;
        const cmd = ["awww", "img", "-t", transition];
        if (Config.wallpaperTransitionDuration > 0) cmd.push("--transition-duration", String(Config.wallpaperTransitionDuration));
        cmd.push(path);
        applyProc.command = cmd;
        applyProc.running = true;
    }
    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: (code, st) => {
            if (code === 0) {
                root.status = "Wallpaper set";
                root.statusIsError = false;
                ThemeCtl.applyImage(root.applying);      // recolour the shell from it (only when Quick Settings > Wallpaper colours is on)
            } else {
                const msg = String(applyErr.text || "").trim().split("\n")[0];
                root.status = "awww could not set it" + (msg !== "" ? ": " + msg : " (is awww-daemon running?)");
                root.statusIsError = true;
            }
            root.applying = "";
            root.refreshCurrent();
            statusClear.restart();
        }
    }
    Timer { id: statusClear; interval: 4000; onTriggered: { root.status = ""; root.statusIsError = false; } }

    // called by the tab every time it opens
    function open() {
        status = "";
        statusIsError = false;
        awwwProbe.running = true;
        refreshCurrent();
        if (files.length === 0 || Date.now() - scannedAt > 60000) { scannedAt = Date.now(); rescan(); }
    }
    property double scannedAt: 0
}
