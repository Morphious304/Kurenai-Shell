pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the window knows, always read back from the kurenai-* programs:
//   schema / values   kurenai-conf schema --json, kurenai-conf list --json      (every setting, its default, "changed")
//   status            kurenai-ctl status --json                                 (shell, lock, hooks, colours, tools)
// Nothing is cached on disk by this window. A setting you change is shown immediately and then confirmed by reading it
// back, so what you see is what kurenai-conf really holds.
Singleton {
    id: root

    property var schema: []              // [{ group, key, type, default, min, max, choices, label, help }]
    property var values: ({})            // key -> { value, def, changed }
    property string settingsFile: ""
    property bool schemaLoaded: false
    property bool confMissing: false     // kurenai-conf could not be run at all

    property var status: ({})
    property bool statusLoaded: false

    // ---- settings --------------------------------------------------------------------------------------------------
    function meta(key) {
        for (let i = 0; i < schema.length; i++) if (schema[i].key === key) return schema[i];
        return null;
    }
    function rowsOf(group) { return schema.filter(r => r.group === group); }

    function val(key) {
        const v = values[key];
        if (v !== undefined) return v.value;
        const m = meta(key);
        return m ? m.default : undefined;
    }
    function isChanged(key) { const v = values[key]; return v !== undefined && v.changed === true; }
    function countChanged() { let n = 0; for (const k in values) if (values[k].changed) n++; return n; }

    function _arg(v) {
        if (Array.isArray(v)) return v.join(",");
        if (typeof v === "boolean") return v ? "true" : "false";
        return String(v);
    }
    // the text `kurenai-conf set` is given for a value (also what "Show command" prints)
    function setArgs(key, v) { return ["set", key, _arg(v)]; }

    function set(key, v) {
        const cur = values[key];
        const next = Object.assign({}, values);
        next[key] = { value: v, def: cur ? cur.def : (meta(key) ? meta(key).default : v), changed: true };
        values = next;                                     // shown at once; the read-back below corrects it if it was refused
        Cli.run("kurenai-conf", setArgs(key, v), res => { if (!res.ok) reloadValues(); });
    }
    function reset(key) { Cli.run("kurenai-conf", ["reset", key]); }
    function resetAll() { Cli.run("kurenai-conf", ["reset", "--all"]); }

    function reloadSchema() {
        Cli.json("kurenai-conf", ["schema", "--json"], (d, res) => {
            if (Array.isArray(d)) { schema = d; schemaLoaded = true; confMissing = false; }
            else if (!schemaLoaded) confMissing = true;
        });
    }
    function reloadValues() {
        Cli.json("kurenai-conf", ["list", "--json"], (d, res) => {
            if (!d || !Array.isArray(d.settings)) return;
            const m = {};
            for (let i = 0; i < d.settings.length; i++) {
                const s = d.settings[i];
                m[s.key] = { value: s.value, def: s.default, changed: s.changed === true };
            }
            values = m;
            settingsFile = d.file || "";
        });
    }
    function reloadStatus() {
        Cli.json("kurenai-ctl", ["status", "--json"], (d, res) => {
            if (d) { status = d; statusLoaded = true; }
        });
    }
    function reloadAll() { reloadSchema(); reloadValues(); reloadStatus(); }

    // ---- small readers for pages -------------------------------------------------------------------------------------
    function hook(name) { return status.hooks ? status.hooks[name] === true : false; }
    function tool(name) { return status.tools ? status.tools[name] === true : false; }
    function theme() { return status.theme || ({}); }

    Connections {
        target: Cli
        // after any change: read the real state back (a short delay merges bursts, such as a slider being dragged)
        function onWrote() { refresh.restart(); }
    }
    Timer { id: refresh; interval: 250; onTriggered: { root.reloadValues(); root.reloadStatus(); } }

    // the shell, lock screen and tools can change without this window (you press a key, a process dies)
    Timer { interval: 5000; repeat: true; running: true; onTriggered: root.reloadStatus() }

    Component.onCompleted: reloadAll()
}
