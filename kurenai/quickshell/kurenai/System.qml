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

    // Emitted every time a brightness reading finished (the OSD uses it, even if the value is unchanged).
    signal brightnessRead()
    // Emitted when the brightness changed by something other than our own slider (Fn keys, brightnessctl
    // from a keybind, auto-dimming). The OSD listens to this.
    signal brightnessChangedExternally()

    property bool _fromEvent: false        // the running read was triggered by a backlight event
    property real _ownUntil: 0             // our own slider just wrote: do not report that as "external"
    property bool brightnessLive: false    // the udev watcher is up (otherwise: poll while the panel is open)

    // If a read is already running it may predate the change we care about, so run one more after it.
    property bool _readAgain: false
    function refreshBrightness() {
        if (readProc.running) _readAgain = true;
        else readProc.running = true;
    }

    // flags that make brightnessctl use the same curve as the user's brightness keybinds
    readonly property var _curveArgs: {
        const a = [];
        if (Config.brightnessExponent > 0) a.push("-e" + Config.brightnessExponent);
        if (Config.brightnessMin > 0) a.push("-n" + Config.brightnessMin);
        return a;
    }

    // Debounced: dragging a slider sends at most one request per ~70 ms (the last value wins).
    property real _pending: -1
    function setBrightness(v) {
        brightness = Math.max(0.01, Math.min(1, v));       // never fully black (1% floor)
        _ownUntil = Date.now() + 1200;
        _pending = brightness;
        if (!sendTimer.running) sendTimer.start();
    }
    Timer {
        id: sendTimer
        interval: 70
        onTriggered: {
            const pct = Math.round(root._pending * 100);
            Quickshell.execDetached(["brightnessctl", "-c", "backlight"].concat(root._curveArgs).concat(root._devArgs).concat(["set", pct + "%"]));
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
                    // raw ratio -> the same perceptual scale the keybinds use (brightnessctl -eK: raw = pct^K)
                    const raw = parseFloat(p[2]) / parseFloat(p[4]);
                    const e = Config.brightnessExponent;
                    const next = e > 0 ? Math.pow(raw, 1 / e) : raw;
                    const changed = Math.abs(next - root.brightness) > 0.004;
                    const external = root._fromEvent && Date.now() > root._ownUntil;
                    root.brightness = next;
                    root.brightnessState = "ok";
                    root.brightnessRead();
                    if (changed && external) root.brightnessChangedExternally();
                }
            }
        }
        onExited: (code, status) => {
            if (code === 2) root.brightnessState = "missing";
            else if (code !== 0) root.brightnessState = "nodevice";
            if (root._readAgain) { root._readAgain = false; readProc.running = true; }
        }
    }

    // ---- live updates -------------------------------------------------------------------------
    // The kernel announces every backlight change (Fn keys, brightnessctl, auto-dim...) as a udev "change"
    // event for the backlight subsystem; `udevadm monitor` (part of systemd) prints one line per event.
    // So this is event-driven: no polling, no sysfs scraping. Several events in quick succession (a held
    // key) are merged into one read.
    // A read that finishes within ~0.7 s of a backlight event counts as "changed by something else".
    // (A time window, not a one-shot flag, so it does not matter which of two overlapping reads finishes first.)
    Timer { id: fromEventClear; interval: 700; onTriggered: root._fromEvent = false }
    Timer {
        id: brightnessEvent
        interval: 40
        onTriggered: { root._fromEvent = true; fromEventClear.restart(); root.refreshBrightness(); }
    }

    Process {
        id: udevMon
        // exit 2 = udevadm not installed. stdbuf makes sure each line arrives immediately, not in blocks.
        command: ["sh", "-c",
                  "command -v udevadm >/dev/null 2>&1 || exit 2; " +
                  "if command -v stdbuf >/dev/null 2>&1; then exec stdbuf -oL udevadm monitor --udev --subsystem-match=backlight; " +
                  "else exec udevadm monitor --udev --subsystem-match=backlight; fi"]
        stdout: SplitParser {
            onRead: line => {
                root.brightnessLive = true;
                if (line.indexOf("(backlight)") >= 0) brightnessEvent.restart();
            }
        }
        onExited: (code, status) => {
            root.brightnessLive = false;
            if (code !== 2) udevRestart.start();       // it died unexpectedly: try again shortly
        }
    }
    Timer { id: udevRestart; interval: 5000; onTriggered: udevMon.running = true }

    // Fallback only (no udevadm): refresh twice a second while the quick-settings panel is open.
    Timer {
        interval: 500
        repeat: true
        running: !root.brightnessLive && UiState.quickSettingsOpen && root.brightnessState === "ok"
        onTriggered: root.refreshBrightness()
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
    property string lockTool: ""          // first installed of Config.lockTools; "" = no Lock entry
    property bool lockDaemon: false       // the KURENAI lock screen process (qs -c kurenai-lock) is running
    property string shutdownTool: ""      // hyprshutdown (graceful logout) if installed

    function openTool(cmd) { if (cmd !== "") Quickshell.execDetached([cmd]); }

    Process {
        id: toolProbe
        command: ["sh", "-c",
                  "f() { for c in \"$@\"; do command -v \"$c\" >/dev/null 2>&1 && { echo \"$c\"; return; }; done; echo; }; " +
                  "echo \"audio=$(f " + Config.audioTools.join(" ") + ")\"; " +
                  "echo \"network=$(f " + Config.networkTools.join(" ") + ")\"; " +
                  "echo \"bluetooth=$(f " + Config.bluetoothTools.join(" ") + ")\"; " +
                  "echo \"lock=$(f " + Config.lockTools.join(" ") + ")\"; " +
                  "echo \"shutdown=$(f hyprshutdown)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const kv = lines[i].split("=");
                    if (kv[0] === "audio") root.audioTool = kv[1] || "";
                    else if (kv[0] === "network") root.networkTool = kv[1] || "";
                    else if (kv[0] === "bluetooth") root.bluetoothTool = kv[1] || "";
                    else if (kv[0] === "lock") root.lockTool = kv[1] || "";
                    else if (kv[0] === "shutdown") root.shutdownTool = kv[1] || "";
                }
            }
        }
    }

    // Checked at start and each time the power menu opens (the locker may start a moment after the shell).
    function probeLockDaemon() { if (!lockProbe.running) lockProbe.running = true; }
    Process {
        id: lockProbe
        command: ["sh", "-c", "pgrep -f '(^|/)(qs|quickshell)( .*)? -c kurenai-lock( |$)' >/dev/null"]
        onExited: (code, status) => root.lockDaemon = (code === 0)
    }

    Component.onCompleted: {
        lockProbe.running = true;
        readProc.running = true;
        udevMon.running = true;
        nightProbe.running = true;
        ppdProbe.running = true;
        toolProbe.running = true;
    }
}
