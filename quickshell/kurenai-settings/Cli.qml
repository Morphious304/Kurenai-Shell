pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The ONLY way this window changes or reads anything: it runs the kurenai-* programs (kurenai-ctl, kurenai-conf,
// kurenai-hypr, kurenai-clip) from PATH or ~/.local/bin, with the arguments as a list (never a shell string), so a value
// typed into a field can never become a command. Every command is also written to the Output drawer, exactly as you
// could type it in a terminal ("Show command" on each control prints the same text).
//
//   Cli.read(prog, args, cb)   run now, quietly (loading pages)        cb({ ok, code, out, err, text })
//   Cli.json(prog, args, cb)   same, and parse stdout as JSON          cb(data|null, result)
//   Cli.run(prog, args, cb)    one at a time, in order, logged (changes)
//   Cli.detach(prog, args)     start and forget (lock preview, debug ...)
//   Cli.wrote                  signal: a run() command finished (pages re-read their state)
Singleton {
    id: root

    property var log: []                // [{ id, time, cmd, state: running|ok|failed|started, out }]
    property int active: 0
    readonly property bool busy: active > 0
    property string lastError: ""
    property int nextId: 1
    signal wrote()
    signal failed(string cmd, string message)

    property var _queue: []
    property bool _writing: false
    property var _exited: []

    // finds the program on PATH, else in ~/.local/bin (the same trick ThemeCtl.qml uses for kurenai-ctl)
    readonly property string runner: 'p="$1"; shift; k=$(command -v "$p" || echo "$HOME/.local/bin/$p"); exec "$k" "$@"'

    function okProg(p) { return /^kurenai-[a-z]+$/.test(String(p)); }

    function quote(a) {
        a = String(a);
        return /^[A-Za-z0-9_.,:=\/@%+~-]+$/.test(a) ? a : "'" + a.replace(/'/g, "'\\''") + "'";
    }
    // the exact command line as you could type it
    function show(prog, args) { return [prog].concat((args || []).map(quote)).join(" "); }

    function _argv(prog, args) { return ["sh", "-c", runner, "sh", prog].concat((args || []).map(String)); }

    // ---- log -------------------------------------------------------------------------------------------------------
    function _addLog(cmd, state) {
        const e = { id: nextId++, time: Qt.formatTime(new Date(), "HH:mm:ss"), cmd: cmd, state: state, out: "" };
        const l = log.concat([e]);
        log = l.length > 200 ? l.slice(l.length - 200) : l;
        return e.id;
    }
    function _updateLog(id, state, out) {
        log = log.map(e => e.id === id ? { id: e.id, time: e.time, cmd: e.cmd, state: state, out: out } : e);
    }
    function clearLog() { log = log.filter(e => e.state === "running"); }

    // ---- start one process -----------------------------------------------------------------------------------------
    function _start(job) {
        if (!okProg(job.prog)) {
            _finishJob(job, { ok: false, code: 2, out: "", err: "refused: only kurenai-* programs can be run", text: "refused: only kurenai-* programs can be run" });
            return;
        }
        active += 1;
        if (!job.quiet) job.logId = _addLog(show(job.prog, job.args), "running");
        const p = procC.createObject(root, { command: _argv(job.prog, job.args), job: job });
        p.running = true;
    }

    function _try(p) {
        if (p.ended && p.soDone && p.seDone) _done(p);
    }
    function _done(p) {
        if (p.finished) return;
        p.finished = true;
        _exited = _exited.filter(x => x !== p);        // so the sweep below never touches it after it is destroyed
        const out = String(p.collected().out || "");
        const err = String(p.collected().err || "");
        const res = { ok: p.exitCode === 0, code: p.exitCode, out: out, err: err, text: (out + (err !== "" ? (out !== "" && !out.endsWith("\n") ? "\n" : "") + err : "")).trim() };
        active = Math.max(0, active - 1);
        _finishJob(p.job, res);
        p.destroy(50);
    }
    function _finishJob(job, res) {
        if (job.logId !== undefined) _updateLog(job.logId, res.ok ? "ok" : "failed", res.text);
        if (!res.ok && !job.quiet) {
            const line = res.text.split("\n").filter(l => l.trim() !== "").slice(-1)[0] || "the command failed";
            lastError = line;
            failed(show(job.prog, job.args), line);
        }
        try { if (job.cb) job.cb(res); } catch (e) { console.warn("[kurenai-settings] callback error:", e); }
        if (job.serial) { _writing = false; wrote(); _pump(); }
    }

    Component {
        id: procC
        Process {
            id: p
            property var job: null
            property bool ended: false
            property bool soDone: false
            property bool seDone: false
            property bool finished: false
            property int exitCode: -1
            function collected() { return { out: so.text, err: se.text }; }
            stdout: StdioCollector { id: so; onStreamFinished: { p.soDone = true; root._try(p); } }
            stderr: StdioCollector { id: se; onStreamFinished: { p.seDone = true; root._try(p); } }
            onExited: (code, status) => {
                p.exitCode = code;
                p.ended = true;
                root._exited = root._exited.concat([p]);
                sweep.restart();            // if a stream never reports its end, finish anyway
                root._try(p);
            }
        }
    }
    Timer {
        id: sweep
        interval: 600
        onTriggered: {
            const list = root._exited;
            root._exited = [];
            for (let i = 0; i < list.length; i++) if (!list[i].finished) root._done(list[i]);
        }
    }

    // ---- public API ------------------------------------------------------------------------------------------------
    function read(prog, args, cb) { _start({ prog: prog, args: args || [], cb: cb, quiet: true, serial: false }); }

    function json(prog, args, cb) {
        read(prog, args, res => {
            let d = null;
            if (res.ok) { try { d = JSON.parse(res.out); } catch (e) { d = null; } }
            if (cb) cb(d, res);
        });
    }

    function run(prog, args, cb) {
        _queue = _queue.concat([{ prog: prog, args: args || [], cb: cb, quiet: false, serial: true }]);
        _pump();
    }
    function _pump() {
        if (_writing || _queue.length === 0) return;
        const job = _queue[0];
        _queue = _queue.slice(1);
        _writing = true;
        _start(job);
    }

    function detach(prog, args) {
        if (!okProg(prog)) return;
        const id = _addLog(show(prog, args), "started");
        _updateLog(id, "started", "started in the background (it keeps running if you close this window)");
        Quickshell.execDetached(_argv(prog, args));
    }
}
