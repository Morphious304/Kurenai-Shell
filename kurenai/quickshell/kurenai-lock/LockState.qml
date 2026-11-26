pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// All lock-screen state and the authentication logic, in ONE place.
//
// Security notes:
//  * The ONLY way out of the lock is PAM reporting Success (password or fingerprint) -> succeed().
//    The IPC interface has no "unlock" function on purpose.
//  * The typed password is kept in `pending` only until Enter, then handed to PAM and dropped. It is never
//    logged, written to disk, or shown (only its LENGTH is, as petals). QML strings cannot be wiped from
//    memory; that is a limit of every QML-based locker.
//  * If this process dies, the compositor keeps the screen locked (ext-session-lock). `kurenai-lock.active`
//    (in $XDG_RUNTIME_DIR, gone after reboot) lets a restarted process re-lock immediately.
Singleton {
    id: root

    // Breadcrumbs for diagnosing problems: timestamped, written to the locker's log. NEVER pass secrets here
    // (the typed password is not logged anywhere; only states and counts are).
    function log(msg) { console.log("[kurenai-lock " + Qt.formatDateTime(new Date(), "HH:mm:ss.zzz") + "] " + msg); }

    // ------------------------------------------------------------------ state
    // idle | input | verifying | wrong | cooldown | success
    property string phase: "idle"
    property bool engaged: false
    property bool unlocking: false         // the success fade-out is playing (the view fades only for THIS, never for a stale phase)
    property bool preview: false           // preview window: real PAM check, but nothing is locked
    property int length: 0                 // how many characters are typed (drives the petals)
    property string pending: ""            // the typed password (see notes above)
    property int attempts: 0
    property int wrongCount: 0             // increments on every wrong password (triggers the shake)
    property int cooldownLeft: 0
    property string message: ""            // an error that needs reading (e.g. PAM trouble)
    property int notifCount: 0

    property string fpState: "off"         // off | ready | retry | unavailable
    property string fpHint: ""
    property int fpFailures: 0

    property bool pamOk: false
    property string pamProblem: "checking the PAM configuration"

    signal clearInput()                    // every surface empties its text field
    signal unlockRequested()               // authentication succeeded: the controller releases the lock
    signal relockRequested()               // a previous locker died while locked

    // ------------------------------------------------------------------ authentication (password)
    readonly property string pamDir: Config.pamDirectory !== "" ? Config.pamDirectory : "pam"

    PamContext {
        id: pwPam
        configDirectory: root.pamDir
        config: Config.pamPassword

        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);          // hand the password to PAM ...
                root.pending = "";              // ... and drop our copy right away
                root.length = 0;
                root.clearInput();
            }
        }
        onCompleted: result => root.onPasswordResult(result)
        onError: err => console.warn("[kurenai-lock] PAM (password) error:", err)
    }

    function setPassword(text) {
        if (phase === "verifying" || phase === "cooldown" || phase === "success") return;
        pending = text;
        length = text.length;
        if (phase === "wrong" || phase === "idle") phase = "input";
        message = "";
        idleTimer.restart();
    }

    function clear() {
        pending = "";
        length = 0;
        message = "";
        clearInput();
        if (phase === "wrong") phase = "input";
        idleTimer.restart();
    }

    function submit() {
        if (!engaged) return;
        if (phase !== "input" && phase !== "wrong") return;
        if (pending === "" || pwPam.active) return;
        phase = "verifying";
        message = "";
        if (!pwPam.start()) {
            phase = "input";
            pending = "";
            length = 0;
            clearInput();
            message = "Could not start authentication.";
        }
    }

    function onPasswordResult(result) {
        if (phase === "success") return;
        if (result === PamResult.Success) { succeed(); return; }

        pending = "";
        length = 0;
        clearInput();

        if (result === PamResult.Error) {
            // Not "wrong password": the authentication system itself failed. Say so, and say how to get out.
            phase = "input";
            message = "Authentication error. Fingerprint may still work. Else: Ctrl+Alt+F3, then run  kurenai-ctl lock-recover";
            return;
        }
        // Failed or MaxTries
        attempts += 1;
        wrongCount += 1;
        if (attempts >= Config.maxAttempts) startCooldown();
        else phase = "wrong";
    }

    function startCooldown() {
        phase = "cooldown";
        cooldownLeft = Config.cooldownSeconds;
        cooldownTimer.restart();
    }
    Timer {
        id: cooldownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.cooldownLeft -= 1;
            if (root.cooldownLeft <= 0) {
                stop();
                root.attempts = 0;
                root.phase = "input";
            }
        }
    }

    // ------------------------------------------------------------------ authentication (fingerprint)
    // A SECOND PAM conversation, running at the same time as the password one: whichever succeeds unlocks.
    PamContext {
        id: fpPam
        configDirectory: root.pamDir
        config: Config.pamFingerprint

        onPamMessage: {
            if (responseRequired) { abort(); root.fpState = "unavailable"; }     // not something a fingerprint check should ask
            else if (message !== "") root.fpHint = message;
        }
        onCompleted: result => root.onFingerprintResult(result)
        onError: err => { console.warn("[kurenai-lock] PAM (fingerprint) error:", err); root.fpState = "unavailable"; }
    }

    function fpStart() {
        if (!Config.fingerprint || !engaged || phase === "success") return;
        if (fpState === "unavailable" || fpPam.active) return;
        fpHint = "";
        fpState = fpPam.start() ? "ready" : "unavailable";
    }

    function onFingerprintResult(result) {
        if (phase === "success" || !engaged) return;
        if (result === PamResult.Success) { succeed(); return; }
        if (result === PamResult.Error) { fpState = "unavailable"; return; }
        fpState = "retry";
        if (result === PamResult.MaxTries) {                 // the reader says: stop for a while
            fpHint = "Fingerprint paused";
            fpRetry.interval = 20000;
        } else {
            fpFailures += 1;
            fpHint = "Fingerprint not recognised";
            fpRetry.interval = 1500;
        }
        fpRetry.restart();
    }
    Timer { id: fpRetry; onTriggered: root.fpStart() }

    // ------------------------------------------------------------------ success
    function succeed() {
        if (phase === "success") return;
        log("authentication succeeded: releasing the lock");
        phase = "success";
        unlocking = true;
        pending = "";
        length = 0;
        clearInput();
        fpRetry.stop();
        cooldownTimer.stop();
        if (pwPam.active) pwPam.abort();
        if (fpPam.active) fpPam.abort();
        unlockTimer.start();              // let the fade-out play, then release
    }
    Timer { id: unlockTimer; interval: 220; onTriggered: root.unlockRequested() }

    // ------------------------------------------------------------------ lock / unlock lifecycle
    function engage() {
        log("engage (was engaged=" + engaged + ", phase=" + phase + ", preview=" + preview + ")");
        // No early return: every lock starts from a completely clean state, whatever the previous one left behind.
        engaged = true;
        unlocking = false;
        phase = "idle";
        pending = "";
        length = 0;
        attempts = 0;
        message = "";
        fpFailures = 0;
        fpState = Config.fingerprint ? "off" : "unavailable";
        clearInput();
        if (!preview) Quickshell.execDetached(["sh", "-c", 'touch "$XDG_RUNTIME_DIR/kurenai-lock.active"']);
        refreshWallpapers();
        refreshNotifCount();
        fpStart();
        idleTimer.restart();
    }

    function disengage() {
        log("disengage (was engaged=" + engaged + ", phase=" + phase + ")");
        engaged = false;
        unlocking = false;
        fpRetry.stop();
        cooldownTimer.stop();
        idleTimer.stop();
        if (pwPam.active) pwPam.abort();
        if (fpPam.active) fpPam.abort();
        pending = "";
        length = 0;
        phase = "idle";
        if (!preview) Quickshell.execDetached(["sh", "-c", 'rm -f "$XDG_RUNTIME_DIR/kurenai-lock.active"']);
        refreshWallpapers();                // so the next lock starts with the current wallpaper
    }

    // any activity wakes the input field; a quiet field fades away again
    function touch() {
        if (phase === "idle") phase = "input";
        idleTimer.restart();
    }
    Timer {
        id: idleTimer
        interval: Config.idleHideSeconds * 1000
        onTriggered: if (root.length === 0 && (root.phase === "input" || root.phase === "wrong")) root.phase = "idle"
    }

    // ------------------------------------------------------------------ wallpaper (awww)
    property var wallpapers: ({})          // output name -> file:// url
    property string wallpaperAny: ""
    readonly property string fallbackWallpaper: Config.wallpaper !== "" ? "file://" + encodeURI(Config.wallpaper) : ""
    function wallpaperFor(name) { return wallpapers[name] || wallpaperAny || fallbackWallpaper; }

    function refreshWallpapers() {
        if (Config.useAwww && !awwwProc.running) awwwProc.running = true;
    }
    Process {
        id: awwwProc
        command: ["awww", "query", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const groups = Array.isArray(d) ? [d] : Object.keys(d).map(k => d[k]);
                    const map = {};
                    let first = "";
                    for (let g = 0; g < groups.length; g++) {
                        const list = Array.isArray(groups[g]) ? groups[g] : [];
                        for (let i = 0; i < list.length; i++) {
                            const o = list[i];
                            if (o && o.name && o.displaying && o.displaying.image) {
                                const u = "file://" + encodeURI(o.displaying.image);
                                map[o.name] = u;
                                if (first === "") first = u;
                            }
                        }
                    }
                    root.wallpapers = map;
                    root.wallpaperAny = first;
                } catch (e) {
                    console.warn("[kurenai-lock] could not read `awww query -j` output; using the fallback background");
                }
            }
        }
    }

    // ------------------------------------------------------------------ notification COUNT (written by the main shell)
    function refreshNotifCount() { if (!notifProc.running) notifProc.running = true; }
    Process {
        id: notifProc
        command: ["sh", "-c", 'cat "$XDG_RUNTIME_DIR/kurenai-notifications" 2>/dev/null || echo 0']
        stdout: StdioCollector { onStreamFinished: root.notifCount = Math.max(0, parseInt(text) || 0) }
    }
    Timer { interval: 5000; repeat: true; running: root.engaged; onTriggered: root.refreshNotifCount() }

    // ------------------------------------------------------------------ start-up checks
    // We refuse to lock when the password check cannot work: locking yourself out is worse than not locking.
    readonly property string pwConfigPath: Config.pamDirectory !== ""
        ? Config.pamDirectory + "/" + Config.pamPassword
        : Qt.resolvedUrl("pam/" + Config.pamPassword).toString().replace(/^file:\/\//, "")

    Process {
        id: pamProbe
        command: ["sh", "-c", 'grep -q "^auth" "$1" 2>/dev/null', "sh", root.pwConfigPath]
        onExited: (code, status) => {
            root.pamOk = (code === 0);
            root.pamProblem = code === 0 ? "" : "password PAM file missing or without an auth rule: " + root.pwConfigPath;
        }
    }

    // A previous locker died while the screen was locked: lock again right away.
    Process {
        id: flagProbe
        command: ["sh", "-c", 'test -e "$XDG_RUNTIME_DIR/kurenai-lock.active"']
        onExited: (code, status) => { if (code === 0 && !root.preview) root.relockRequested(); }
    }

    Component.onCompleted: {
        pamProbe.running = true;
        refreshWallpapers();
        flagProbe.running = true;
    }
}
