import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The only file that touches the compositor's session lock.
//   * lock:    requestLock() (from IPC)  ->  the lock is requested from the compositor
//   * unlock:  ONLY when LockState reports a successful PAM check (password or fingerprint)
//   * there is deliberately no IPC function that unlocks
// While locked, Hyprland covers every output with the lock surfaces below. If this process dies, the screen
// stays locked.
//
// `held` is OUR OWN record of "this process holds the lock". We do not trust WlSessionLock.locked for that:
// it is a control property, and in practice it kept reading true after an unlock without emitting a change
// signal (seen in the logs), which left every later lock showing an invisible UI (a grey screen).
Scope {
    id: root

    property bool held: false
    readonly property bool isLocked: held

    function requestLock(force) {
        LockState.log("lock requested (force=" + force + ", held=" + held + ", sessionLock.locked=" + sessionLock.locked
                      + ", phase=" + LockState.phase + ", pamOk=" + LockState.pamOk + ", screens=" + Quickshell.screens.length + ")");
        if (held) return "already locked";
        if (!force && !LockState.pamOk) return "refused: " + LockState.pamProblem;
        held = true;
        LockState.engage();                 // always starts from a clean state
        acquire();
        denied.restart();
        return "locked";
    }

    // Ask the compositor for the lock. If the Quickshell object still claims to be locked from an earlier round,
    // reset it first (setting an equal value would do nothing), then lock again a moment later.
    function acquire() {
        if (sessionLock.locked) {
            LockState.log("lock object still reports locked=true: resetting it, then locking again");
            relockTimer.restart();          // BEFORE the reset, so the change handler knows this is intentional
            sessionLock.locked = false;
        } else {
            sessionLock.locked = true;
            LockState.log("session lock requested from the compositor");
        }
    }
    Timer {
        id: relockTimer
        interval: 60
        onTriggered: {
            sessionLock.locked = true;
            LockState.log("session lock requested from the compositor (after reset)");
        }
    }

    // The ONLY way out: authentication succeeded. Cleanup happens HERE, not in a change handler.
    function release() {
        LockState.log("releasing the session lock");
        held = false;
        denied.stop();
        sessionLock.locked = false;
        LockState.disengage();
    }

    // If the compositor never grants the lock, do not stay "held": that would leave the re-lock flag file behind.
    Timer {
        id: denied
        interval: 3000
        onTriggered: {
            LockState.log("3 s after the request: held=" + root.held + " sessionLock.locked=" + sessionLock.locked);
            if (root.held && !sessionLock.locked) { root.held = false; LockState.disengage(); }
        }
    }

    WlSessionLock {
        id: sessionLock

        onLockedChanged: {
            LockState.log("sessionLock.locked is now " + locked);
            // the compositor ended the lock behind our back (not our unlock, not our own reset): clean up
            if (!locked && root.held && !relockTimer.running) {
                LockState.log("the lock ended without our unlock");
                root.held = false;
                LockState.disengage();
            }
        }
        onSecureChanged: LockState.log("compositor reports secure=" + secure + " (all screens covered)")

        WlSessionLockSurface {
            id: surface
            color: Theme.bg                       // the default is white: avoid a flash before the view paints
            LockView {
                anchors.fill: parent
                screenName: surface.screen ? surface.screen.name : ""
            }
        }
    }

    Connections {
        target: LockState
        function onUnlockRequested() { root.release(); }
        // A previous locker died while locked: re-lock no matter what (the screen is ALREADY locked; refusing
        // here would leave it stuck on the compositor's placeholder).
        function onRelockRequested() { root.requestLock(true); }
    }

    IpcHandler {
        target: "lock"
        function lock(): string { return root.requestLock(false); }
        function status(): string { return root.isLocked ? "locked" : "unlocked"; }
    }
}
