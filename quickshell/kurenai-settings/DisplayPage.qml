import QtQuick

// Monitors and input through `kurenai-hypr`. Applying always starts a revert timer: unless you press Keep, the last
// confirmed settings come back by themselves (the timer is a background process, so it works even if this window closes).
Page {
    id: page
    title: "Display and input"
    kanji: "画"
    subtitle: "Resolution, scale and position of each monitor, keyboard layout and touchpad. Changes are saved first, then applied with a safety timer."

    property var monitors: []
    property var staged: ({})
    property bool trial: false          // a revert timer is running
    property int secsLeft: 0                // seconds, counted here for display only
    property bool hooked: false
    readonly property int timeout: 15

    function sv(key) { const v = staged[key]; return v === undefined ? "" : String(v); }
    function reloadStaged() { Cli.json("kurenai-hypr", ["show", "--json"], (d, res) => { if (d && typeof d === "object") staged = d; }); }
    function reloadMonitors() { Cli.json("kurenai-hypr", ["monitors", "--json"], (d, res) => { if (Array.isArray(d)) monitors = d; }); }
    function reloadStatus() {
        Cli.read("kurenai-hypr", ["status"], res => {
            trial = /trial:\s+running/.test(res.out);
            hooked = /hook active:\s+yes/.test(res.out);
            if (trial && secsLeft <= 0) secsLeft = 1;
        });
    }
    function reloadAll() { reloadStaged(); reloadMonitors(); reloadStatus(); }
    Component.onCompleted: reloadAll()
    Connections { target: Cli; function onWrote() { later.restart(); } }
    Timer { id: later; interval: 300; onTriggered: page.reloadAll() }

    function stage(args) { Cli.run("kurenai-hypr", args); }
    function mon(name, key, v) { stage(["monitor", name, key, String(v)]); }
    function inp(key, v) { stage(["input", key, String(v)]); }
    function apply() {
        Cli.run("kurenai-hypr", ["apply", "--timeout", String(timeout)], res => {
            if (res.ok) { secsLeft = timeout; trial = true; }
        });
    }

    Timer {
        interval: 1000; repeat: true; running: page.trial && page.secsLeft > 0
        onTriggered: { page.secsLeft -= 1; if (page.secsLeft <= 0) { page.trial = false; page.reloadAll(); } }
    }

    // the safety banner while a trial is running
    Rectangle {
        visible: page.trial
        width: parent.width
        height: 76
        radius: Theme.rLg
        color: Theme.alpha(Theme.amber, 0.14)
        border.width: 2
        border.color: Theme.amber
        Column {
            x: Theme.s4; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: "Keep these display settings?"; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase + 2; font.weight: Font.DemiBold; color: Theme.text }
            Text { text: page.secsLeft > 1 ? "Going back by itself in " + page.secsLeft + " seconds if you do nothing." : "Going back by itself shortly."
                   font.family: Theme.fontUi; font.pixelSize: Theme.fsBase; color: Theme.text2 }
        }
        Row {
            anchors { right: parent.right; rightMargin: Theme.s4; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2
            Btn { width: 100; implicitHeight: 34; center: true; text: "Keep"; checked: true
                  onClicked: Cli.run("kurenai-hypr", ["confirm"], r => { page.trial = false; page.secsLeft = 0; }) }
            Btn { width: 120; implicitHeight: 34; center: true; text: "Go back now"
                  onClicked: Cli.run("kurenai-hypr", ["revert"], r => { page.trial = false; page.secsLeft = 0; }) }
        }
    }

    Card {
        title: "Apply"
        hint: "Your choices below are saved as you make them. Apply writes ~/.config/hypr/kurenai-hypr.lua, reloads Hyprland and starts a " + page.timeout + " second safety timer. The first Apply also adds one marked line to hyprland.lua (after a backup)."
        Line {
            title: "Apply the saved display and input choices"
            sub: page.hooked ? "The hook is active." : "The hook is not in hyprland.lua yet; Apply adds it."
            command: Cli.show("kurenai-hypr", ["apply", "--timeout", String(page.timeout)])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Apply"; checked: true; enabled: !page.trial; onClicked: page.apply() }
        }
        Line {
            title: "Forget all saved monitor and input choices"
            sub: "Then Apply to go back to what hyprland.lua says."
            command: Cli.show("kurenai-hypr", ["reset", "--all"])
            divider: false
            ConfirmBtn { label: "Forget choices"; implicitWidth: 190; onConfirmed: Cli.run("kurenai-hypr", ["reset", "--all"]) }
        }
    }

    Repeater {
        model: page.monitors
        Card {
            id: mc
            required property var modelData
            readonly property string name: modelData.name
            title: modelData.name + "  ·  " + modelData.width + "x" + modelData.height + " @ " + Number(modelData.refreshRate).toFixed(0) + " Hz  ·  scale " + modelData.scale
            hint: "Now on screen. The boxes show what you saved (empty means “not set, leave it as hyprland.lua says”)."

            Line {
                title: "Mode"
                sub: "Like 1920x1080@60, or preferred, highres, highrr, maxwidth."
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "mode", page.sv("monitor." + mc.name + ".mode") || "preferred"])
                KField { width: 200; mono: true; placeholder: "preferred"; value: page.sv("monitor." + mc.name + ".mode"); onCommit: t => page.mon(mc.name, "mode", t) }
            }
            Line {
                title: "Position"
                sub: "auto, or X by Y in pixels, like 1920x0."
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "position", page.sv("monitor." + mc.name + ".position") || "auto"])
                KField { width: 200; mono: true; placeholder: "auto"; value: page.sv("monitor." + mc.name + ".position"); onCommit: t => page.mon(mc.name, "position", t) }
            }
            Line {
                wide: true
                title: "Scale"
                sub: "1.25 or 1.5 are common on a 15-inch 4K panel."
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "scale", page.sv("monitor." + mc.name + ".scale") || "1"])
                Seg { width: parent.width; itemWidth: 72; model: ["auto", "1", "1.25", "1.5", "1.75", "2"]; current: page.sv("monitor." + mc.name + ".scale"); onPicked: v => page.mon(mc.name, "scale", v) }
            }
            Line {
                wide: true
                title: "Rotation"
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "transform", page.sv("monitor." + mc.name + ".transform") || "0"])
                Seg { width: parent.width; itemWidth: 110
                      model: [{ value: "0", label: "Normal" }, { value: "1", label: "90°" }, { value: "2", label: "180°" }, { value: "3", label: "270°" }]
                      current: page.sv("monitor." + mc.name + ".transform"); onPicked: v => page.mon(mc.name, "transform", v) }
            }
            Line {
                wide: true
                title: "Adaptive sync (VRR)"
                sub: "Needs a monitor that supports it."
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "vrr", page.sv("monitor." + mc.name + ".vrr") || "0"])
                Seg { width: parent.width; itemWidth: 130
                      model: [{ value: "0", label: "Off" }, { value: "1", label: "On" }, { value: "2", label: "Fullscreen only" }]
                      current: page.sv("monitor." + mc.name + ".vrr"); onPicked: v => page.mon(mc.name, "vrr", v) }
            }
            Line {
                title: "Switch this monitor off"
                sub: page.monitors.length < 2 ? "Refused for your only monitor, so you cannot black out the screen." : "Its windows move to the other monitor."
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "disabled", "true"])
                KToggle { checked: page.sv("monitor." + mc.name + ".disabled") === "true"; enabled: page.monitors.length > 1
                          onToggled: page.mon(mc.name, "disabled", checked ? "false" : "true") }
            }
            Line {
                title: "Forget this monitor's saved choices"
                command: Cli.show("kurenai-hypr", ["monitor", mc.name, "reset"])
                divider: false
                Btn { width: 130; implicitHeight: 32; center: true; text: "Forget"; onClicked: page.stage(["monitor", mc.name, "reset"]) }
            }
        }
    }
    Text {
        visible: page.monitors.length === 0
        width: parent.width
        text: "No monitors reported. Is Hyprland running? (kurenai-hypr monitors)"
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBase
        color: Theme.muted
    }

    Card {
        title: "Keyboard"
        Line {
            title: "Layout"
            sub: "Like us, or us,ru for two layouts."
            command: Cli.show("kurenai-hypr", ["input", "kb_layout", page.sv("input.kb_layout") || "us"])
            KField { width: 200; mono: true; placeholder: "(Hyprland default)"; value: page.sv("input.kb_layout"); onCommit: t => page.inp("kb_layout", t) }
        }
        Line {
            title: "Variant"
            command: Cli.show("kurenai-hypr", ["input", "kb_variant", page.sv("input.kb_variant") || "intl"])
            KField { width: 200; mono: true; value: page.sv("input.kb_variant"); onCommit: t => page.inp("kb_variant", t) }
        }
        Line {
            title: "Options"
            sub: "Like grp:alt_shift_toggle or caps:escape."
            command: Cli.show("kurenai-hypr", ["input", "kb_options", page.sv("input.kb_options") || "caps:escape"])
            KField { width: 260; mono: true; value: page.sv("input.kb_options"); onCommit: t => page.inp("kb_options", t) }
        }
        Line {
            title: "Repeat rate"
            sub: "Characters per second when a key is held (0 to 200)."
            command: Cli.show("kurenai-hypr", ["input", "repeat_rate", page.sv("input.repeat_rate") || "25"])
            KField { width: 90; mono: true; numeric: true; value: page.sv("input.repeat_rate"); onCommit: t => page.inp("repeat_rate", t) }
        }
        Line {
            title: "Repeat delay"
            sub: "Milliseconds before repeating starts (0 to 2000)."
            command: Cli.show("kurenai-hypr", ["input", "repeat_delay", page.sv("input.repeat_delay") || "600"])
            KField { width: 90; mono: true; numeric: true; value: page.sv("input.repeat_delay"); onCommit: t => page.inp("repeat_delay", t) }
        }
        Line {
            title: "Num Lock on at start"
            command: Cli.show("kurenai-hypr", ["input", "numlock_by_default", "true"])
            divider: false
            KToggle { checked: page.sv("input.numlock_by_default") === "true"; onToggled: page.inp("numlock_by_default", checked ? "false" : "true") }
        }
    }

    Card {
        title: "Mouse and touchpad"
        Line {
            wide: true
            title: "Focus follows mouse"
            sub: "1 is the usual focus-follows-mouse; 0 means focus changes only when you click."
            command: Cli.show("kurenai-hypr", ["input", "follow_mouse", page.sv("input.follow_mouse") || "1"])
            Seg { width: parent.width; itemWidth: 70; model: ["0", "1", "2", "3"]; current: page.sv("input.follow_mouse"); onPicked: v => page.inp("follow_mouse", v) }
        }
        Line {
            wide: true
            title: "Pointer acceleration"
            command: Cli.show("kurenai-hypr", ["input", "accel_profile", page.sv("input.accel_profile") || "flat"])
            Seg { width: parent.width; itemWidth: 110
                  model: [{ value: "adaptive", label: "Adaptive" }, { value: "flat", label: "Flat" }]
                  current: page.sv("input.accel_profile"); onPicked: v => page.inp("accel_profile", v) }
        }
        Line {
            title: "Pointer sensitivity"
            sub: "-1 slowest, 0 default, 1 fastest."
            command: Cli.show("kurenai-hypr", ["input", "sensitivity", page.sv("input.sensitivity") || "0"])
            KField { width: 90; mono: true; numeric: true; value: page.sv("input.sensitivity"); onCommit: t => page.inp("sensitivity", t) }
        }
        Line {
            title: "Natural scrolling (touchpad)"
            command: Cli.show("kurenai-hypr", ["input", "touchpad.natural_scroll", "true"])
            KToggle { checked: page.sv("input.touchpad.natural_scroll") === "true"; onToggled: page.inp("touchpad.natural_scroll", checked ? "false" : "true") }
        }
        Line {
            title: "Tap to click (touchpad)"
            command: Cli.show("kurenai-hypr", ["input", "touchpad.tap-to-click", "true"])
            KToggle { checked: page.sv("input.touchpad.tap-to-click") === "true"; onToggled: page.inp("touchpad.tap-to-click", checked ? "false" : "true") }
        }
        Line {
            title: "Ignore the touchpad while typing"
            command: Cli.show("kurenai-hypr", ["input", "touchpad.disable_while_typing", "true"])
            divider: false
            KToggle { checked: page.sv("input.touchpad.disable_while_typing") === "true"; onToggled: page.inp("touchpad.disable_while_typing", checked ? "false" : "true") }
        }
    }
}
