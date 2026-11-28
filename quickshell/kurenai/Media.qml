pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The ONE media state (bar indicator, media panel, OSD). Uses Quickshell's MPRIS support, so it works
// with anything that speaks MPRIS: Spotify, mpv (with mpv-mpris), Firefox/Chromium, VLC, ...
// Nothing is fetched from the internet: artwork is shown only when the player gives a LOCAL file.
Singleton {
    id: root

    // dbus name of the player the user switched to in the panel ("" = automatic)
    property string pickedId: ""

    readonly property var list: Mpris.players.values

    // Automatic choice: the one you picked, else the first that is playing, else the first one.
    readonly property var player: {
        const l = list;
        if (l.length === 0) return null;
        if (pickedId !== "") {
            for (let i = 0; i < l.length; i++) if (l[i].dbusName === pickedId) return l[i];
        }
        for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i];
        return l[0];
    }

    readonly property bool has: !!player
    readonly property bool playing: has && player.isPlaying
    readonly property string title: has ? (player.trackTitle || "") : ""
    readonly property string artist: has ? (player.trackArtist || "") : ""
    readonly property string album: has ? (player.trackAlbum || "") : ""
    readonly property string identity: has ? (player.identity || player.desktopEntry || "Player") : ""

    readonly property bool canPrev: has && player.canGoPrevious
    readonly property bool canNext: has && player.canGoNext
    readonly property bool canToggle: has && player.canTogglePlaying
    readonly property bool canSeek: has && player.canSeek && player.positionSupported && player.lengthSupported
    readonly property bool hasPosition: has && player.positionSupported && player.lengthSupported && player.length > 0
    readonly property real length: hasPosition ? player.length : 0
    readonly property real position: hasPosition ? Math.min(player.position, player.length) : 0

    // Local artwork only. file:// URLs (and plain paths) are shown; http(s) is NEVER loaded, so
    // players that only offer web artwork (Spotify, most browsers) get the fallback tile.
    readonly property string artSource: {
        const u = has ? (player.trackArtUrl || "") : "";
        if (u.indexOf("file://") === 0) return u;
        if (u.charAt(0) === "/") return "file://" + u;
        return "";
    }

    function togglePlaying() { if (canToggle) player.togglePlaying(); }
    function next()          { if (canNext) player.next(); }
    function previous()      { if (canPrev) player.previous(); }
    function seekTo(sec)     { if (canSeek) player.position = Math.max(0, Math.min(player.length, sec)); }

    // Switch between several running players (panel button).
    function cyclePlayer() {
        const l = list;
        if (l.length < 2) return;
        let idx = 0;
        for (let i = 0; i < l.length; i++) if (player && l[i].dbusName === player.dbusName) idx = i;
        pickedId = l[(idx + 1) % l.length].dbusName;
    }
    readonly property int playerIndex: {
        for (let i = 0; i < list.length; i++) if (player && list[i].dbusName === player.dbusName) return i + 1;
        return 0;
    }

    // MPRIS does not push the position continuously. While the panel is open and music plays, ask for
    // an update once a second (this is the method the Quickshell docs describe); otherwise: no timer.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing && UiState.mediaOpen
        onTriggered: if (root.player) root.player.positionChanged()
    }

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // "Title - Artist", shortened for the bar
    function barText() {
        let t = title !== "" ? title : "Unknown title";
        if (artist !== "") t += " \u2013 " + artist;
        const n = Config.mediaBarChars;
        return t.length > n ? t.substring(0, n - 1) + "\u2026" : t;
    }
}
