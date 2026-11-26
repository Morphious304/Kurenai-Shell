pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// KURENAI design tokens. Every colour, size, radius, font and timing lives here.
// QML colours with alpha are #AARRGGBB (alpha FIRST).
//
// COLOURS follow the wallpaper when "wallpaper colours" are on (kurenai-ctl theme on): matugen writes
// $XDG_DATA_HOME/kurenai/palette.json and this file watches it, so the shell AND the lock screen (which has
// its own copy of this file) change together with a short cross-fade. The values below are the built-in
// KURENAI colours. They are used when the file is missing, switched off, unreadable, or fails the contrast check:
// a bad palette can never make the shell unreadable.
Singleton {
    id: root

    // ---- the palette file ---------------------------------------------------------------------------------------
    readonly property string paletteFile:
        (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/kurenai/palette.json"
    property var pal: ({})               // validated colours from the file; {} = built-in colours
    readonly property bool dynamic: pal.bg !== undefined
    property string _lastText: ""

    // palette key -> built-in value
    readonly property var defaults: ({
        bg: "#242424", surface: "#30302F", raised: "#3A3535", scrim: "#B3141414",
        panelBg: "#F2262625", panelBorder: "#3DF4E8BE",
        text: "#F4E8BE", text2: "#D8CFB3", muted: "#A8A393", inkOnAccent: "#1A1A1A",
        accent: "#F04436", accentText: "#FF6B5C", accentDeep: "#B8281E", teal: "#70A6A0", rose: "#C98DB5",
        border: "#1FF4E8BE", borderStrong: "#47F4E8BE"
    })
    // these follow the wallpaper's main colour; "pinAccent" in the file keeps them vermilion
    readonly property var accentKeys: ["accent", "accentText", "accentDeep", "inkOnAccent", "teal", "rose"]
    property bool pinAccent: false

    // `pal` already holds the colours that are shown (pinning and repairs are applied when the file is loaded)
    function pick(name) {
        const v = pal[name];
        return v === undefined ? defaults[name] : v;
    }

    // ---- contrast guard (WCAG relative luminance) ---------------------------------------------------------------------
    function _lum(c) {
        const h = String(c).replace("#", "");
        const x = h.slice(-6);
        const f = v => { v = v / 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
        return 0.2126 * f(parseInt(x.slice(0, 2), 16)) + 0.7152 * f(parseInt(x.slice(2, 4), 16)) + 0.0722 * f(parseInt(x.slice(4, 6), 16));
    }
    function contrast(a, b) {
        const la = _lum(a), lb = _lum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
    // Move a colour toward black (dir -1) or white (dir +1) in 10% steps until it reads against every colour in `against`.
    // Only plain #RRGGBB values are touched; anything else is returned unchanged and the guard below rejects it.
    function _shift(hex, f, dir) {
        const h = hex.slice(1);
        const ch = i => {
            const v = parseInt(h.slice(i, i + 2), 16);
            const o = dir < 0 ? Math.round(v * (1 - f)) : Math.round(v + (255 - v) * f);
            return (o < 16 ? "0" : "") + o.toString(16);
        };
        return "#" + ch(0) + ch(2) + ch(4);
    }
    function ensureReadable(hex, against, min, dir) {
        if (typeof hex !== "string" || !/^#[0-9a-fA-F]{6}$/.test(hex)) return hex;
        for (let f = 0; f <= 0.91; f += 0.1) {
            const v = f === 0 ? hex : _shift(hex, f, dir);
            let ok = true;
            for (let i = 0; i < against.length; i++) if (!(contrast(v, against[i]) >= min)) { ok = false; break; }
            if (ok) return v;
        }
        return hex;
    }
    // the colours that will be shown for a palette from the file: pinned vermilion applied, two tokens made readable
    function effective(colors, pinned) {
        const c = Object.assign({}, colors);
        if (pinned) for (let i = 0; i < accentKeys.length; i++) c[accentKeys[i]] = defaults[accentKeys[i]];
        // the "deep" accent is a fill with text on top (some schemes make it light: darken it)
        c.accentDeep = ensureReadable(c.accentDeep, [c.text], 4.5, -1);
        // accent-coloured text sits on surface and raised (pinned vermilion can be a hair short on a light panel: lighten it)
        c.accentText = ensureReadable(c.accentText, [c.surface, c.raised], 4.5, +1);
        return c;
    }

    // true only if every key is a well-formed colour and the readable pairs are readable
    function validPalette(c) {
        if (!c || typeof c !== "object") return false;
        const keys = Object.keys(defaults);
        for (let i = 0; i < keys.length; i++) {
            const v = c[keys[i]];
            if (typeof v !== "string" || !/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v)) return false;
        }
        const need = [["text", "surface", 7], ["text", "raised", 7], ["text", "bg", 7],
                      ["text2", "surface", 4.5], ["muted", "surface", 4.3], ["muted", "raised", 3.5],
                      ["accentText", "surface", 4.5], ["accentText", "raised", 4.5],
                      ["inkOnAccent", "accent", 4.5], ["text", "accentDeep", 4.5]];
        for (let j = 0; j < need.length; j++) {
            if (contrast(c[need[j][0]], c[need[j][1]]) < need[j][2]) return false;
        }
        return true;
    }

    function _load(t) {
        if (t === _lastText) return;
        let d;
        try { d = JSON.parse(t); } catch (e) { retry.restart(); return; }   // half-written file: keep what we have, look again
        _lastText = t;
        if (!d || d.enabled !== true || !d.colors) { pal = ({}); pinAccent = false; return; }
        const eff = effective(d.colors, d.pinAccent === true);
        if (!validPalette(eff)) {
            console.warn("[kurenai] palette.json fails the contrast check; using the built-in colours");
            pal = ({}); pinAccent = false; return;
        }
        pinAccent = d.pinAccent === true;
        pal = eff;
    }
    function reloadPalette() { palFile.reload(); }

    FileView {
        id: palFile
        path: root.paletteFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._load(text())
        onLoadFailed: error => {}           // missing file = keep the current colours
    }
    Timer { id: retry; interval: 150; onTriggered: palFile.reload() }
    // safety net in case a file replacement is missed by the watcher (a 1 KB read; ignored when unchanged)
    Timer { interval: 3000; repeat: true; running: true; onTriggered: palFile.reload() }

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ---- surfaces ---------------------------------------------------------------------------------------------------
    property color bg:      pick("bg")
    property color surface: pick("surface")
    property color raised:  pick("raised")
    property color scrim:   pick("scrim")
    property color panelBg: pick("panelBg")           // panels/popups: 95% opaque (>=10:1 for text on any wallpaper)
    property color panelBorder: pick("panelBorder")   // text colour @ 24%

    // ---- text (contrast checked against bg / surface / raised) -----------------------------------------------------------
    property color text:     pick("text")        // built-in: bone
    property color text2:    pick("text2")       // ivory
    property color muted:    pick("muted")
    property color inkOnAccent: pick("inkOnAccent")   // text ON accent fills

    // ---- accents ------------------------------------------------------------------------------------------------------
    property color accent:     pick("accent")      // built-in: vermilion. Focus + state. Indicators only, not small text.
    property color accentText: pick("accentText")  // small accent TEXT
    property color accentDeep: pick("accentDeep")  // pressed / destructive fills with light text
    property color teal:       pick("teal")        // secondary interactive
    property color rose:       pick("rose")        // informational
    readonly property color amber: "#F0A333"       // warnings, charging, urgent: fixed on purpose, always reads as a warning

    // ---- lines ---------------------------------------------------------------------------------------------------------
    property color border:       pick("border")        // text colour @ 12%
    property color borderStrong: pick("borderStrong")  // text colour @ 28%

    // cross-fade when the palette changes
    Behavior on bg           { ColorAnimation { duration: root.durSlow } }
    Behavior on surface      { ColorAnimation { duration: root.durSlow } }
    Behavior on raised       { ColorAnimation { duration: root.durSlow } }
    Behavior on scrim        { ColorAnimation { duration: root.durSlow } }
    Behavior on panelBg      { ColorAnimation { duration: root.durSlow } }
    Behavior on panelBorder  { ColorAnimation { duration: root.durSlow } }
    Behavior on text         { ColorAnimation { duration: root.durSlow } }
    Behavior on text2        { ColorAnimation { duration: root.durSlow } }
    Behavior on muted        { ColorAnimation { duration: root.durSlow } }
    Behavior on inkOnAccent  { ColorAnimation { duration: root.durSlow } }
    Behavior on accent       { ColorAnimation { duration: root.durSlow } }
    Behavior on accentText   { ColorAnimation { duration: root.durSlow } }
    Behavior on accentDeep   { ColorAnimation { duration: root.durSlow } }
    Behavior on teal         { ColorAnimation { duration: root.durSlow } }
    Behavior on rose         { ColorAnimation { duration: root.durSlow } }
    Behavior on border       { ColorAnimation { duration: root.durSlow } }
    Behavior on borderStrong { ColorAnimation { duration: root.durSlow } }

    // ---- spacing (4px unit), radii, sizes -------------------------------------
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s6: 24

    readonly property int rSm: 6
    readonly property int rMd: 10
    readonly property int rLg: 14

    readonly property int barHeight: 36
    readonly property int itemHeight: 24

    readonly property int popupMargin: 12        // gap between a panel and the screen edge / bar
    readonly property int notifWidth: 360
    readonly property int centerWidth: 380
    readonly property int launcherWidth: 560
    readonly property int launcherRowHeight: 44
    readonly property int qsWidth: 380

    // ---- motion -----------------------------------------------------------
    readonly property int durFast: 120
    readonly property int durBase: 220
    readonly property int durSlow: 320

    // ---- type -------------------------------------------------------------
    readonly property string fontUi:      "Adwaita Sans"
    readonly property string fontMono:    "JetBrainsMono Nerd Font"
    readonly property string fontIcon:    "JetBrainsMono Nerd Font"
    readonly property string fontDisplay: "Noto Serif CJK JP"   // decorative kanji only; Qt falls back if absent

    readonly property int fsSmall: 11
    readonly property int fsBase:  13
    readonly property int fsIcon:  14

    // ---- clock format -----------------------------------------------------
    readonly property string timeFormat: "ddd d MMM  HH:mm"

    // ---- Nerd Font glyphs (Font Awesome range, escaped so the file stays plain ASCII) ---
    readonly property var icons: ({
        volUp:    "\uf028",
        volDown:  "\uf027",
        volOff:   "\uf026",
        mic:      "\uf130",
        micOff:   "\uf131",
        wifi:     "\uf1eb",
        wired:    "\uf1e6",
        offline:  "\uf127",
        bat4:     "\uf240",
        bat3:     "\uf241",
        bat2:     "\uf242",
        bat1:     "\uf243",
        bat0:     "\uf244",
        bolt:     "\uf0e7",
        bell:     "\uf0f3",
        bellOff:  "\uf1f6",
        sliders:  "\uf1de",
        close:    "\uf00d",
        trash:    "\uf1f8",
        search:   "\uf002",
        star:     "\uf005",
        starO:    "\uf006",
        clock:    "\uf017",
        lock:     "\uf023",
        bluetooth:"\uf293",
        coffee:   "\uf0f4",
        moon:     "\uf186",
        sun:      "\uf185",
        chevDown: "\uf078",
        chevUp:   "\uf077",
        check:    "\uf00c",
        cog:      "\uf013",
        headphones:"\uf025",
        play:     "\uf04b",
        pause:    "\uf04c",
        prev:     "\uf048",
        next:     "\uf051",
        music:    "\uf001",
        calendar: "\uf073",
        power:    "\uf011",
        signout:  "\uf08b",
        reboot:   "\uf021",
        bed:      "\uf236",
        chevL:    "\uf053",
        chevR:    "\uf054",
        clipboard:"\uf0ea",
        pin:      "\uf08d",
        image:    "\uf03e",
        file:     "\uf15c",
        chart:    "\uf080",
        thermo:   "\uf2c9",
        hdd:      "\uf0a0"
    })
}
