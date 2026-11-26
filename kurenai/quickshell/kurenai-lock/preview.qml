import QtQuick
import Quickshell

// SAFE PREVIEW: the same lock screen in an ordinary window. Nothing is locked.
// It runs the REAL password check (and fingerprint), so this is also how you prove unlocking works
// before the first real lock:   kurenai-ctl lock-preview     (or: qs -p <this file>)
ShellRoot {
    Component.onCompleted: {
        LockState.preview = true;
        LockState.engage();
    }

    Connections {
        target: LockState
        function onUnlockRequested() {
            console.log("[kurenai-lock] preview: authentication accepted (nothing was locked)");
            Qt.quit();
        }
    }

    FloatingWindow {
        title: "KURENAI lock preview"
        implicitWidth: 1280
        implicitHeight: 720
        color: Theme.bg
        LockView { anchors.fill: parent; screenName: "" }
    }
}
