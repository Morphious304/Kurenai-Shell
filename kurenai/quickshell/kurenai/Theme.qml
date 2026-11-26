pragma Singleton
import QtQuick
import Quickshell

// KURENAI design tokens. Every colour, size, radius, font and timing lives here.
// QML colours with alpha are #AARRGGBB (alpha FIRST).
Singleton {
    // ---- surfaces ---------------------------------------------------------
    readonly property color bg:      "#242424"
    readonly property color surface: "#30302F"
    readonly property color raised:  "#3A3535"
    readonly property color scrim:   "#B3141414"
    readonly property color panelBg: "#F2262625"      // panels/popups: 95% charcoal (>=10:1 for bone text on any wallpaper)
    readonly property color panelBorder: "#3DF4E8BE"  // bone @ 24%

    // ---- text (contrast checked against bg / surface / raised) -------------
    readonly property color text:     "#F4E8BE"   // bone
    readonly property color text2:    "#D8CFB3"   // ivory
    readonly property color muted:    "#A8A393"
    readonly property color inkOnAccent: "#1A1A1A"   // text ON vermilion fills (4.6:1)

    // ---- accents ----------------------------------------------------------
    readonly property color accent:     "#F04436" // vermilion: focus + state. Indicators only, not small text.
    readonly property color accentText: "#FF6B5C" // small red TEXT (4.7:1 on surface)
    readonly property color accentDeep: "#B8281E" // pressed / destructive fills with bone text
    readonly property color teal:       "#70A6A0" // secondary interactive
    readonly property color rose:       "#C98DB5" // informational
    readonly property color amber:      "#F0A333" // warnings, charging, urgent

    // ---- lines ------------------------------------------------------------
    readonly property color border:       "#1FF4E8BE"  // bone @ 12%
    readonly property color borderStrong: "#47F4E8BE"  // bone @ 28%

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
        chevR:    "\uf054"
    })
}
