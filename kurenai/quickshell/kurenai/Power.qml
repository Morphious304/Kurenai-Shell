pragma Singleton
import QtQuick
import Quickshell

// Session power actions. Plain, non-root commands only (never sudo): systemd's logind allows the
// active local session to suspend/reboot/power off. Which actions exist is decided by what is
// really installed, nothing is assumed (see System.lockTool).
Singleton {
    id: root

    readonly property bool canLock: System.lockDaemon || System.lockTool !== ""
    readonly property string lockLabel: System.lockDaemon ? "KURENAI lock" : System.lockTool

    function lockNow() {
        if (System.lockDaemon) Quickshell.execDetached(["qs", "-c", "kurenai-lock", "ipc", "call", "lock", "lock"]);
        else if (System.lockTool !== "") Quickshell.execDetached([System.lockTool]);
    }

    // Entries for the menu. `confirm` = needs an explicit second click.
    readonly property var actions: {
        const a = [];
        if (canLock) a.push({ id: "lock", icon: Theme.icons.lock, label: "Lock", detail: lockLabel, confirm: false });
        a.push({ id: "suspend", icon: Theme.icons.bed, label: "Suspend", detail: "Sleep, keep your session", confirm: false });
        a.push({ id: "logout", icon: Theme.icons.signout, label: "Log out", detail: "Closes your apps and session", confirm: true });
        a.push({ id: "reboot", icon: Theme.icons.reboot, label: "Reboot", detail: "Restart the computer", confirm: true });
        a.push({ id: "poweroff", icon: Theme.icons.power, label: "Shut down", detail: "Turn the computer off", confirm: true });
        return a;
    }

    // Callers (PowerMenu) are responsible for asking first when `confirm` is true.
    function run(id) {
        switch (id) {
        case "lock":     lockNow(); break;
        case "suspend":
            if (Config.lockBeforeSuspend && System.lockDaemon)
                // lock first (the call returns at once), give the compositor a moment, then sleep
                Quickshell.execDetached(["sh", "-c", "qs -c kurenai-lock ipc call lock lock >/dev/null 2>&1; sleep 1; systemctl suspend"]);
            else
                Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "logout":   Compositor.logout(); break;
        case "reboot":   Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        }
    }
}
