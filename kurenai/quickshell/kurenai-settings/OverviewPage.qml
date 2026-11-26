import QtQuick

Page {
    id: page
    title: "Overview"
    kanji: "概"
    subtitle: "What is running, what is connected, and the quick checks. This window works with the shell stopped."

    readonly property var st: Store.status
    readonly property bool shellUp: st.shell !== undefined && st.shell.running === true
    readonly property var toolInfo: [
        { k: "qs",            what: "Quickshell: runs the shell and this window" },
        { k: "hyprctl",       what: "talks to Hyprland (reload, monitors, bind check)" },
        { k: "awww",          what: "sets the wallpaper" },
        { k: "matugen",       what: "makes colours from the wallpaper" },
        { k: "cliphist",      what: "clipboard history storage" },
        { k: "wl-copy",       what: "copies from the clipboard history" },
        { k: "rofi",          what: "the Rofi launcher (kept as an alternative)" },
        { k: "brightnessctl", what: "brightness keys and the slider" },
        { k: "hyprsunset",    what: "night light" },
        { k: "notify-send",   what: "test notifications" },
        { k: "busctl",        what: "tells who owns notifications" }
    ]

    Card {
        visible: Store.confMissing
        title: "kurenai-conf was not found"
        hint: "Most pages need it. Run install.sh again from the KURENAI folder (it copies kurenai-conf, kurenai-hypr and kurenai-settings to ~/.local/bin)."
    }

    Card {
        title: "Shell"
        Line {
            title: page.shellUp ? "The KURENAI shell is running" : "The KURENAI shell is stopped"
            sub: !Store.statusLoaded ? "Checking..."
               : !Store.tool("qs") ? "Quickshell (qs) was not found on PATH, so the shell cannot be started from here."
               : page.shellUp ? "Process " + (st.shell.pids || []).join(", ") : "Bar, launcher and panels are not shown. Settings and the Rofi launcher still work."
            command: Cli.show("kurenai-ctl", [page.shellUp ? "restart" : "start"])
            Row {
                spacing: Theme.s2
                Btn { width: 84; implicitHeight: 32; center: true; text: "Start"; enabled: !page.shellUp && Store.tool("qs"); onClicked: Cli.run("kurenai-ctl", ["start"]) }
                Btn { width: 84; implicitHeight: 32; center: true; text: "Restart"; enabled: page.shellUp; onClicked: Cli.run("kurenai-ctl", ["restart"]) }
                Btn { width: 84; implicitHeight: 32; center: true; text: "Stop"; enabled: page.shellUp; onClicked: Cli.run("kurenai-ctl", ["stop"]) }
            }
        }
        Line {
            title: "Lock screen process"
            sub: st.lock && st.lock.running ? "Running" + (st.lock.state ? " (" + st.lock.state + ")" : "") : "Not running. Manage it on the Lock screen page."
            divider: false
            Btn { width: 120; implicitHeight: 32; center: true; text: "Open page"; onClicked: App.go("lock") }
        }
    }

    Card {
        title: "Checks"
        hint: "Read-only. The result appears in the Output drawer."
        Line {
            title: "Health check"
            sub: "Versions, services, fonts, files and conflicts."
            command: Cli.show("kurenai-ctl", ["validate"])
            Btn { width: 120; implicitHeight: 32; center: true; text: "Validate"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["validate"]); } }
        }
        Line {
            title: "Keybind check"
            sub: "Compares KURENAI's binds with what Hyprland has active."
            command: Cli.show("kurenai-ctl", ["binds-check"])
            Btn { width: 120; implicitHeight: 32; center: true; text: "Check binds"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["binds-check"]); } }
        }
        Line {
            title: "Back up my Hyprland and Quickshell config"
            sub: "Copies ~/.config/hypr and ~/.config/quickshell into a dated folder. Every change KURENAI makes does this first."
            command: Cli.show("kurenai-ctl", ["backup"])
            divider: false
            Btn { width: 120; implicitHeight: 32; center: true; text: "Back up now"; onClicked: Cli.run("kurenai-ctl", ["backup"]) }
        }
    }

    Card {
        title: "Connected to Hyprland"
        hint: "Each is ONE marked line in hyprland.lua. Turn them on or off on the Startup and hooks page."
        Repeater {
            model: [["theme", "Look (borders, gaps, motion)"], ["binds", "Keybinds"], ["autostart", "Start the shell with the session"], ["lock", "Lock screen process"], ["hypr", "Monitors and input"]]
            Line {
                id: hl
                required property var modelData
                title: modelData[1]
                readonly property bool on: Store.hook(modelData[0])
                Text {
                    text: hl.on ? "active" : "off"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall + 1
                    color: hl.on ? Theme.teal : Theme.muted
                }
            }
        }
        Btn { width: 200; implicitHeight: 32; center: true; text: "Manage hooks"; onClicked: App.go("hooks") }
    }

    Card {
        title: "Programs found"
        hint: "Missing ones only switch off the feature that needs them."
        Repeater {
            model: page.toolInfo
            Line {
                required property var modelData
                title: modelData.k
                sub: modelData.what
                divider: true
                Text {
                    text: Store.tool(modelData.k) ? "found" : "missing"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall + 1
                    color: Store.tool(modelData.k) ? Theme.teal : Theme.amber
                }
            }
        }
    }
}
