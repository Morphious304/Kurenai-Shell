import QtQuick

Page {
    id: page
    title: "Keybinds"
    kanji: "鍵"
    subtitle: "KURENAI's own binds. Change a chord, switch one off, or put it back. Your other binds in hyprland.lua are never touched."

    property var binds: []
    property string only: ""
    readonly property bool hooked: Store.hook("binds")
    readonly property var shown: {
        const t = only.toLowerCase().trim();
        return t === "" ? binds : binds.filter(b => (b.label + " " + b.chord + " " + b.default).toLowerCase().indexOf(t) >= 0);
    }
    readonly property int changedCount: binds.filter(b => b.state !== "default").length

    function reload() { Cli.json("kurenai-conf", ["binds", "list", "--json"], (d, res) => { if (Array.isArray(d)) binds = d; }); }
    Component.onCompleted: reload()
    Connections { target: Cli; function onWrote() { later.restart(); } }
    Timer { id: later; interval: 300; onTriggered: page.reload() }

    Card {
        title: "Binds in Hyprland"
        hint: page.hooked ? "KURENAI's binds are active." : "The binds line is not in hyprland.lua, so none of these keys do anything yet. Check first, then enable."
        Line {
            title: "Use KURENAI's keybinds"
            sub: "One marked line in hyprland.lua (backup first). Run the check before enabling: it lists clashes with binds you already have."
            command: Cli.show("kurenai-ctl", [page.hooked ? "disable-binds" : "enable-binds"])
            KToggle { checked: page.hooked; onToggled: Cli.run("kurenai-ctl", [page.hooked ? "disable-binds" : "enable-binds"]) }
        }
        Line {
            title: "Check for clashes"
            command: Cli.show("kurenai-ctl", ["binds-check"])
            divider: false
            Btn { width: 130; implicitHeight: 32; center: true; text: "Check binds"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["binds-check"]); } }
        }
    }

    Card {
        title: page.binds.length + " binds" + (page.changedCount > 0 ? "  (" + page.changedCount + " changed)" : "")
        hint: "Type the new chord like SUPER + ALT + K and press Enter. Modifiers: SUPER, ALT, CTRL, SHIFT. The last part is the key."
        KField { width: parent.width; placeholder: "Filter binds"; onTextChanged: page.only = text }
        Repeater {
            model: page.shown
            Line {
                id: bl
                required property var modelData
                required property int index
                title: modelData.label
                sub: modelData.state === "default" ? "Default: " + modelData.default
                   : modelData.state === "disabled" ? "Switched off (default was " + modelData.default + ")"
                   : "Default was " + modelData.default
                changed: modelData.state !== "default"
                command: Cli.show("kurenai-conf", ["binds", "set", modelData.default, modelData.chord])
                divider: index < page.shown.length - 1
                onResetClicked: Cli.run("kurenai-conf", ["binds", "reset", modelData.default])
                Row {
                    spacing: Theme.s2
                    KField {
                        width: 230
                        mono: true
                        enabled: bl.modelData.state !== "disabled"
                        value: bl.modelData.state === "disabled" ? "(off)" : bl.modelData.chord
                        onCommit: t => Cli.run("kurenai-conf", ["binds", "set", bl.modelData.default, t])
                    }
                    Btn {
                        width: 84; implicitHeight: 32; center: true
                        text: bl.modelData.state === "disabled" ? "Turn on" : "Turn off"
                        onClicked: bl.modelData.state === "disabled" ? Cli.run("kurenai-conf", ["binds", "reset", bl.modelData.default])
                                                                    : Cli.run("kurenai-conf", ["binds", "disable", bl.modelData.default])
                    }
                }
            }
        }
    }

    Card {
        title: "Good to know"
        hint: "Changes reload Hyprland by themselves when the binds line is active. The Shortcuts page of the shell still lists the default chords until it learns about remaps (it reads hyprland.lua, not this file)."
    }
}
