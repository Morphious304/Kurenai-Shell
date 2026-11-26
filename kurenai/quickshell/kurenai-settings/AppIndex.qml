pragma Singleton
import QtQuick
import Quickshell

// Installed applications (Quickshell's DesktopEntries, the same source the launcher uses), only to show names and to pick
// favourites. What is a favourite is stored by kurenai-conf, never here.
Singleton {
    id: root

    readonly property var all: {
        const out = [];
        const list = DesktopEntries.applications.values;
        for (let i = 0; i < list.length; i++) if (!list[i].noDisplay) out.push(list[i]);
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }
    function byId(id) {
        for (let i = 0; i < all.length; i++) if (all[i].id === id) return all[i];
        return null;
    }
    function nameOf(id) { const e = byId(id); return e ? e.name : String(id).replace(/\.desktop$/, ""); }
    function find(q, limit) {
        const terms = String(q || "").toLowerCase().split(/\s+/).filter(t => t !== "");
        const out = [];
        if (terms.length === 0) return out;
        for (let i = 0; i < all.length && out.length < (limit || 8); i++) {
            const hay = (all[i].name + " " + (all[i].genericName || "") + " " + all[i].id).toLowerCase();
            let ok = true;
            for (let t = 0; t < terms.length; t++) if (hay.indexOf(terms[t]) < 0) { ok = false; break; }
            if (ok) out.push(all[i]);
        }
        return out;
    }
}
