pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Non-UI system state that has no native Quickshell API, handled with small, one-shot helper
// processes. Nothing here polls: values are read on demand (when the panel opens, after a change).
//
//   brightness    brightnessctl            (hidden-with-explanation if not installed)
//   night light   hyprsunset               (only offered if installed and not already running)
//   power profile availability probe       (the profile itself is Quickshell's PowerProfiles)
//   settings apps  first installed of Config.*Tools
//   keep awake    flag only; Bar.qml attaches the actual IdleInhibitor to a visible window
//
// No root, no passwords, nothing written to disk.
Singleton {
    id: root

    // ------------------------------------------------------------------ keep awake
    property bool idleInhibit: false

    // ------------------------------------------------------------------ brightness
    property string brightnessState: "probing"    // probing | ok | missing | nodevice
    property real brightness: 0                   // 0..1
    property string brightnessName: ""

    readonly property var _devArgs: Config.brightnessDevice !== "" ? ["-d", Config.brightnessDevice] : []

    function refreshBrightness() {
        if (!readProc.running) readProc.running = true;
    }

    // Debounced: dragging a slider sends at most one request per ~70 ms (the last value wins).
    property real _pending: -1
    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));       // never fully black (1% floor)
        _pending = brightness;
        if (!sendTimer.running) sendTimer.start();
    }
    Timer {
        id: sendTimer
        interval: 70
        onTriggered: {
            const pct = Math.round(root._pending * 100);
            Quickshell.execDetached(["brightnessctl", "-c", "backlight"].concat(root._devArgs).concat(["set", pct + "%"]));
            readback.restart();
        }
    }
    Timer { id: readback; interval: 500; onTriggered: root.refreshBrightness() }

    Process {
        id: readProc
        // exit 2 = brightnessctl not installed; other non-zero = no backlight device (e.g. external-only)
        command: ["sh", "-c",
                  "command -v brightnessctl >/dev/null 2>&1 || exit 2; exec brightnessctl -m -c backlight ${1:+-d \"$1\"}",
                  "sh", Config.brightnessDevice]
        stdout: StdioCollector {
            onStreamFinished: {
                // machine format: device,class,current,percent,max
                const p = text.trim().split("\n")[0].split(",");
                if (p.length >= 5 && parseFloat(p[4]) > 0) {
                    root.brightnessName = p[0];
                    root.brightness = parseFloat(p[2]) / parseFloat(p[4]);
                    root.brightnessState = "ok";
                }
            }
        }
        onExited: (code, status) => {
            if (code === 2) root.brightnessState = "missing";
            else if (code !== 0) root.brightnessState = "nodevice";
        }
    }

    // ------------------------------------------------------------------ night light (hyprsunset)
    // unknown | unavailable (not installed) | external (already running, not ours) | off | on
    property string nightLight: "unknown"

    function toggleNightLight() {
        if (nightLight === "off") { nightProc.running = true; nightLight = "on"; }
        else if (nightLight === "on") { nightProc.running = false; nightLight = "off"; }
    }
    Process {
        id: nightProbe
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 || exit 2; pgrep -x hyprsunset >/dev/null 2>&1 && exit 3; exit 0"]
        onExited: (code, status) => root.nightLight = code === 0 ? "off" : code === 3 ? "external" : "unavailable"
    }
    // Owned by the shell: stopping the shell (or the toggle) stops the filter.
    Process {
        id: nightProc
        command: ["hyprsunset", "-t", String(Config.nightLightTemp)]
        onExited: (code, status) => { if (root.nightLight === "on") root.nightLight = "off"; }
    }

    // ------------------------------------------------------------------ power-profiles-daemon
    property bool powerProfilesInstalled: false
    Process {
        id: ppdProbe
        command: ["sh", "-c", "systemctl cat power-profiles-daemon.service >/dev/null 2>&1"]
        onExited: (code, status) => root.powerProfilesInstalled = (code === 0)
    }

    // ------------------------------------------------------------------ settings apps (shortcuts)
    property string audioTool: ""
    property string networkTool: ""
    property string bluetoothTool: ""

    function openTool(cmd) { if (cmd !== "") Quickshell.execDetached([cmd]); }

    Process {
        id: toolProbe
        command: ["sh", "-c",
                  "f() { for c in \"$@\"; do command -v \"$c\" >/dev/null 2>&1 && { echo \"$c\"; return; }; done; echo; }; " +
                  "echo \"audio=$(f " + Config.audioTools.join(" ") + ")\"; " +
                  "echo \"network=$(f " + Config.networkTools.join(" ") + ")\"; " +
                  "echo \"bluetooth=$(f " + Config.bluetoothTools.join(" ") + ")\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const kv = lines[i].split("=");
                    if (kv[0] === "audio") root.audioTool = kv[1] || "";
                    else if (kv[0] === "network") root.networkTool = kv[1] || "";
                    else if (kv[0] === "bluetooth") root.bluetoothTool = kv[1] || "";
                }
            }
        }
    }

    Component.onCompleted: {
        readProc.running = true;
        nightProbe.running = true;
        ppdProbe.running = true;
        toolProbe.running = true;
    }
}
