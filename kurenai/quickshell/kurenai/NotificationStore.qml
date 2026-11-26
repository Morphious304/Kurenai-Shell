pragma Singleton
import QtQuick
import Quickshell
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
