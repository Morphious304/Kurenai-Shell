pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The ONE notification state. The bar badge, the popups, the centre and Do Not Disturb all read
// from here, so they cannot disagree.
//
//   history  = every notification the server is tracking (what the centre shows)
//   popups   = the subset currently shown as transient toasts
//
// A popup disappearing (timeout / close button) never removes it from history.
// Dismissing in the centre removes it for good (and tells the sending app it was closed).
//
// Only one process can own org.freedesktop.Notifications. If mako/dunst/swaync is running,
// this server will not receive anything: see `kurenai-ctl notif-status`.
Singleton {
    id: root

    property bool dnd: false

    // ---- derived state ---------------------------------------------------
    readonly property var tracked: server.trackedNotifications.values
    readonly property var history: {
        const out = [];
        const list = tracked;
        for (let i = list.length - 1; i >= 0; i--) {        // newest first
            if (!list[i].transient) out.push(list[i]);
        }
        return out;
    }
    readonly property int count: history.length
    readonly property bool hasCritical: {
        for (let i = 0; i < history.length; i++) {
            if (history[i].urgency === NotificationUrgency.Critical) return true;
        }
        return false;
    }

    // ids that should currently be visible as popups
    property var popupIds: ({})
    // id -> arrival time (ms). The notification object itself carries no timestamp.
    property var arrivals: ({})

    readonly property var popups: {
        const list = tracked;
        const shown = [];
        for (let i = 0; i < list.length; i++) {
            if (popupIds[list[i].id] === true) shown.push(list[i]);
        }
        if (shown.length <= Config.maxPopups) return shown.reverse();   // newest on top

        // Over the limit: criticals are always kept, then the newest of the rest.
        const crit = shown.filter(n => n.urgency === NotificationUrgency.Critical);
        const rest = shown.filter(n => n.urgency !== NotificationUrgency.Critical);
        const room = Math.max(0, Config.maxPopups - crit.length);
        const keep = crit.concat(rest.slice(Math.max(0, rest.length - room)));
        keep.sort((a, b) => shown.indexOf(a) - shown.indexOf(b));
        return keep.reverse();
    }

    // ---- time ------------------------------------------------------------
    SystemClock { id: clock; precision: SystemClock.Minutes }

    function ago(id) {
        const t = arrivals[id];
        if (t === undefined) return "";
        const mins = Math.floor((clock.date.getTime() - t) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + " min";
        const h = Math.floor(mins / 60);
        if (h < 24) return h + " h";
        return Math.floor(h / 24) + " d";
    }

    // ---- actions ---------------------------------------------------------
    function showPopup(n) {
        const c = Object.assign({}, popupIds);
        c[n.id] = true;
        popupIds = c;
    }
    function hidePopup(id) {
        if (popupIds[id] !== true) return;
        const c = Object.assign({}, popupIds);
        delete c[id];
        popupIds = c;
    }
    function dismiss(n) {           // remove for good
        hidePopup(n.id);
        n.dismiss();
    }
    function clearAll() {
        const list = [];
        for (let i = 0; i < tracked.length; i++) list.push(tracked[i]);
        popupIds = ({});
        for (let i = 0; i < list.length; i++) list[i].dismiss();
        arrivals = ({});
    }
    function toggleDnd() { dnd = !dnd; }

    // The lock screen is a separate process and cannot see this state. It gets a bare NUMBER through a file in
    // $XDG_RUNTIME_DIR (private to you, gone at logout): no titles, no text, no app names.
    onCountChanged: publishTimer.restart()
    Timer {
        id: publishTimer
        interval: 300
        onTriggered: Quickshell.execDetached(["sh", "-c", 'printf %s "$1" > "$XDG_RUNTIME_DIR/kurenai-notifications"', "sh", String(root.count)])
    }

    // ---- who owns org.freedesktop.Notifications ----------------------------------------------------------------------
    // Only one program can. If mako, dunst or swaync has the name, this server never receives a notification, so no
    // popup can ever appear (the centre stays empty too). The check asks the session bus read-only (busctl) and compares
    // the owner's pid with ours: sh's parent is this Quickshell process.
    //   owner: "unknown" (not checked yet / no busctl) | "ours" | "other" | "none"
    property string owner: "unknown"
    property string ownerName: ""
    readonly property bool ownerIsKnownDaemon: ownerName === "mako" || ownerName === "dunst" || ownerName === "swaync"
    function checkOwner() { if (!ownerProbe.running) ownerProbe.running = true; }
    function _ownerRead(text) {
        const t = String(text || "").trim();
        const bar = t.indexOf("|");
        if (bar < 0 || t.charAt(0) === "-") { owner = "unknown"; ownerName = ""; return; }
        const me = t.slice(0, bar).trim();
        const rest = t.slice(bar + 1).trim();
        if (rest === "") { owner = "none"; ownerName = ""; return; }
        const sp = rest.indexOf(" ");
        const pid = sp < 0 ? rest : rest.slice(0, sp);
        const comm = sp < 0 ? "" : rest.slice(sp + 1).trim();
        if (pid === me || comm === "quickshell" || comm === "qs") { owner = "ours"; ownerName = ""; return; }
        if (owner !== "other") console.warn("[kurenai] notifications are owned by '" + comm + "' (pid " + pid + "): popups cannot appear until it is stopped (kurenai-ctl notif-takeover)");
        owner = "other";
        ownerName = comm;
    }
    Process {
        id: ownerProbe
        command: ["sh", "-c", "command -v busctl >/dev/null 2>&1 || { echo '-|'; exit 0; }; " +
                  "o=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | awk -F= '/^PID=/{p=$2} /^Comm=/{c=$2} END{if (p) print p, c}'); " +
                  "echo \"$PPID|$o\""]
        stdout: StdioCollector { id: ownerOut; onStreamFinished: root._ownerRead(ownerOut.text) }
    }
    Timer { interval: 2500; running: true; repeat: false; onTriggered: root.checkOwner() }     // after the server had time to register
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.checkOwner() }

    // stop the other daemon (remembered, undo: kurenai-ctl notif-restore) and restart the shell so it can register
    function takeOver() {
        Quickshell.execDetached(["sh", "-c", 'k=$(command -v kurenai-ctl || echo "$HOME/.local/bin/kurenai-ctl"); "$k" notif-takeover; sleep 1; exec "$k" restart']);
    }

    // ---- server ------------------------------------------------------------
    NotificationServer {
        id: server

        // Capabilities we really render (see NotificationCard.qml).
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        persistenceSupported: true      // the centre keeps history
        // Body text is always rendered as plain text, so we do not advertise markup or links.
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        // keepOnReload defaults to true: notifications survive a Quickshell reload.

        onNotification: n => {
            const a = Object.assign({}, root.arrivals);
            if (a[n.id] === undefined) a[n.id] = Date.now();
            root.arrivals = a;

            n.tracked = true;       // without this the notification would be discarded

            // Notifications carried over from before a Quickshell reload are re-emitted:
            // keep them in history but do not pop them up a second time.
            if (n.lastGeneration) return;

            // Do Not Disturb silences popups, never criticals, and never history.
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.showPopup(n);
        }
    }
}
