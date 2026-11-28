pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's Run tab: type a command, press Enter.
//   * Enter runs it with `sh -c`, detached (it keeps running if the shell restarts). Output is not shown.
//   * Shift+Enter runs it in your terminal (Config.terminal) and waits for Enter before closing.
//   * Suggestions: your recent commands, and programs found on $PATH while you type the first word.
//   * History: $XDG_DATA_HOME/kurenai/runhistory.json (only you can read it). A command that starts with a
//     space is never remembered; Config.runHistory = false remembers nothing at all.
//     Wipe it with `kurenai-ctl reset-launcher`.
Singleton {
    id: root

    property var history: []        // most recent first
    property var execs: []          // program names found on $PATH (sorted, unique)
    property double indexedAt: 0

    readonly property string dataDir:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/kurenai"

    // ---- what the list shows ------------------------------------------------------------------------------
    // Row 0 is always exactly what you typed, so Enter runs what you see. Rows: { kind, cmd }
    //   kind "literal" = what you typed, "history" = an earlier command, "exec" = a program on $PATH
    function suggest(query) {
        const t = (query || "").trim();
        const rows = [];
        const seen = {};
        const add = (kind, cmd) => { if (!seen[cmd]) { seen[cmd] = true; rows.push({ kind: kind, cmd: cmd }); } };

        if (t === "") {
            for (let i = 0; i < history.length && rows.length < 12; i++) add("history", history[i]);
            return rows;
        }

        add("literal", t);

        const low = t.toLowerCase();
        for (let i = 0; i < history.length && rows.length < 7; i++) {
            if (history[i].toLowerCase().indexOf(low) >= 0) add("history", history[i]);
        }

        // program names only while you are typing the first word
        if (!/\s/.test(t)) {
            const hits = [];
            for (let i = 0; i < execs.length; i++) {
                if (execs[i].toLowerCase().startsWith(low)) hits.push(execs[i]);
            }
            hits.sort((a, b) => a.length - b.length || a.localeCompare(b));
            for (let i = 0; i < hits.length && rows.length < 14; i++) add("exec", hits[i]);
        }
        return rows;
    }

    // ---- running -------------------------------------------------------------------------------------------
    function run(cmd, inTerminal, raw) {
        const c = (cmd || "").trim();
        if (c === "") return;
        if (inTerminal) {
            // newline (not ";") so a trailing comment or "&" in your command cannot swallow the pause
            const tail = "\nprintf '\\n[exit %s] press Enter to close ' \"$?\"; read _";
            Quickshell.execDetached([Config.terminal, "sh", "-c", c + tail]);
        } else {
            Quickshell.execDetached(["sh", "-c", c]);
        }
        remember(c, raw !== undefined ? raw : c);
    }

    function remember(cmd, raw) {
        if (!Config.runHistory) return;
        if (/^\s/.test(raw || "")) return;                   // leading space = private, like a shell's ignorespace
        const h = history.filter(x => x !== cmd);
        h.unshift(cmd);
        history = h.slice(0, Config.runHistoryMax);
        save();
    }

    function forget(cmd) {
        history = history.filter(x => x !== cmd);
        save();
    }

    // ---- $PATH index (read-only; refreshed at most every 30 s) ------------------------------------------------
    function refreshIndex() {
        if (Date.now() - indexedAt < 30000 || indexProc.running) return;
        indexProc.running = true;
    }
    Process {
        id: indexProc
        // every executable file directly inside a $PATH directory
        command: ["sh", "-c", 'IFS=:; for d in $PATH; do [ -d "$d" ] && find -L "$d" -maxdepth 1 -type f -perm /111 -printf "%f\\n" 2>/dev/null; done | sort -u']
        stdout: StdioCollector {
            onStreamFinished: {
                root.execs = text.split("\n").filter(x => x !== "");
                root.indexedAt = Date.now();
            }
        }
    }

    // ---- persistence (failures never break the launcher) ------------------------------------------------------
    property bool permsSet: false
    FileView {
        id: file
        path: root.dataDir + "/runhistory.json"
        blockLoading: true
    }

    // the write is asynchronous, so give it a moment to land before tightening the permissions
    Timer {
        id: chmodTimer
        interval: 800
        onTriggered: Quickshell.execDetached(["chmod", "600", file.path])
    }

    function load() {
        if (!Config.runHistory) return;
        try {
            const d = JSON.parse(file.text());
            if (Array.isArray(d.commands))
                history = d.commands.filter(x => typeof x === "string" && x.trim() !== "").slice(0, Config.runHistoryMax);
        } catch (e) {
            // no file yet: start empty
        }
    }

    function save() {
        try {
            file.setText(JSON.stringify({ commands: history }, null, 2) + "\n");
            if (!permsSet) {
                permsSet = true;       // commands can contain secrets: keep the file private to you
                chmodTimer.restart();  // (the installer already creates it 0600; this covers a missing file)
            }
        } catch (e) {
            console.warn("[kurenai] could not save runhistory.json:", e);
        }
    }

    Component.onCompleted: load()
}
