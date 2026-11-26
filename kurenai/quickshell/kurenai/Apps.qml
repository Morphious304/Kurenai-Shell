pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application index for the launcher.
//   * applications come from Quickshell's DesktopEntries (real .desktop files on this system)
//   * favourites and recents are stored locally in  $XDG_DATA_HOME/kurenai/launcher.json
//     (a small JSON file of desktop-entry ids; delete it to reset: `kurenai-ctl reset-launcher`)
Singleton {
    id: root

    property var favorites: []     // desktop entry ids, in the order you added them
    property var recent: []        // desktop entry ids, most recent first

    readonly property string dataDir:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/kurenai"

    // ---- index ---------------------------------------------------------------
    readonly property var all: {
        const out = [];
        const list = DesktopEntries.applications.values;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].noDisplay) out.push(list[i]);
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    function byId(id) {
        for (let i = 0; i < all.length; i++) if (all[i].id === id) return all[i];
        return null;
    }

    function isFavorite(id) { return favorites.indexOf(id) >= 0; }

    // ---- search ----------------------------------------------------------------
    // Empty query: favourites, then recents, then everything else A-Z.
    // Otherwise a simple weighted match over name, generic name, keywords, categories, comment.
    function search(query) {
        const q = (query || "").trim().toLowerCase();
        const limit = Config.launcherMaxResults;

        if (q === "") {
            const seen = {};
            const out = [];
            const push = e => { if (e && !seen[e.id] && out.length < limit) { seen[e.id] = true; out.push(e); } };
            for (let i = 0; i < favorites.length; i++) push(byId(favorites[i]));
            for (let i = 0; i < recent.length; i++) push(byId(recent[i]));
            for (let i = 0; i < all.length; i++) push(all[i]);
            return out;
        }

        const terms = q.split(/\s+/);
        const scored = [];
        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            const name = e.name.toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            const comment = (e.comment || "").toLowerCase();
            const keywords = Array.from(e.keywords || []).join(" ").toLowerCase();
            const cats = Array.from(e.categories || []).join(" ").toLowerCase();

            let total = 0;
            let matchedAll = true;
            for (let t = 0; t < terms.length; t++) {
                const term = terms[t];
                let s = 0;
                if (name === term) s = 120;
                else if (name.startsWith(term)) s = 100;
                else if (name.indexOf(" " + term) >= 0 || name.indexOf("-" + term) >= 0) s = 70;
                else if (name.indexOf(term) >= 0) s = 45;
                else if (generic.indexOf(term) >= 0) s = 25;
                else if (keywords.indexOf(term) >= 0) s = 20;
                else if (cats.indexOf(term) >= 0) s = 10;
                else if (comment.indexOf(term) >= 0) s = 8;
                if (s === 0) { matchedAll = false; break; }
                total += s;
            }
            if (!matchedAll) continue;

            if (isFavorite(e.id)) total += 15;
            const r = recent.indexOf(e.id);
            if (r >= 0) total += Math.max(0, 12 - r);
            scored.push({ e: e, s: total });
        }
        scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name));
        return scored.slice(0, limit).map(x => x.e);
    }

    // ---- launching ---------------------------------------------------------------
    function launch(entry) {
        if (!entry) return;
        if (entry.runInTerminal) {
            // execute() does not open a terminal for Terminal=true apps, so do it ourselves.
            Quickshell.execDetached([Config.terminal].concat(Array.from(entry.command)));
        } else {
            entry.execute();
        }
        noteLaunch(entry.id);
    }

    function noteLaunch(id) {
        const r = recent.filter(x => x !== id);
        r.unshift(id);
        recent = r.slice(0, Config.launcherMaxRecent);
        save();
    }

    function toggleFavorite(id) {
        favorites = isFavorite(id) ? favorites.filter(x => x !== id) : favorites.concat([id]);
        save();
    }

    // ---- persistence (tiny JSON file; failures never break the launcher) ----------
    FileView {
        id: file
        path: root.dataDir + "/launcher.json"
        blockLoading: true
    }

    function load() {
        try {
            const d = JSON.parse(file.text());
            if (Array.isArray(d.favorites)) favorites = d.favorites.filter(x => typeof x === "string");
            if (Array.isArray(d.recent)) recent = d.recent.filter(x => typeof x === "string").slice(0, Config.launcherMaxRecent);
        } catch (e) {
            // missing or unreadable file: start empty (the installer creates it)
        }
    }

    function save() {
        try {
            file.setText(JSON.stringify({ favorites: favorites, recent: recent }, null, 2) + "\n");
        } catch (e) {
            console.warn("[kurenai] could not save launcher.json:", e);
        }
    }

    Component.onCompleted: load()
}
