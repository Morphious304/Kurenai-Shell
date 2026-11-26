import QtQuick

Page {
    id: page
    title: "Colours"
    kanji: "色"
    subtitle: "Make the shell, Hyprland borders and Rofi follow your wallpaper, or keep the built-in KURENAI colours."

    readonly property var th: Store.theme()
    readonly property bool on: th.enabled === true
    readonly property bool haveMatugen: Store.tool("matugen")
    readonly property var types: ["tonal-spot", "vibrant", "fidelity", "expressive", "neutral", "monochrome", "content", "fruit-salad", "rainbow"]

    function toggleCmd(name, now) { return [name, now ? "off" : "on"]; }

    Card {
        title: "Wallpaper colours"
        hint: page.haveMatugen ? "" : "matugen was not found, so wallpaper colours cannot be made (package: matugen). The built-in colours keep working."
        Line {
            title: "Follow the wallpaper"
            sub: page.on ? "On: colours come from the wallpaper that awww shows." : "Off: the built-in KURENAI colours (bone, vermilion on charcoal)."
            command: Cli.show("kurenai-ctl", ["theme", page.on ? "off" : "on"])
            KToggle { enabled: page.haveMatugen; checked: page.on; onToggled: Cli.run("kurenai-ctl", ["theme", page.on ? "off" : "on"]) }
        }
        Line {
            title: "Recolour from the wallpaper now"
            sub: "Use after changing the wallpaper by some other way."
            command: Cli.show("kurenai-ctl", ["theme", "sync"])
            divider: false
            Btn { width: 130; implicitHeight: 32; center: true; text: "Recolour"; enabled: page.haveMatugen; onClicked: Cli.run("kurenai-ctl", ["theme", "sync"]) }
        }
    }

    Card {
        title: "Colour scheme"
        Line {
            wide: true
            title: "Scheme"
            sub: "How colours are picked from the image. Tonal spot is calm; vibrant and rainbow are loud; monochrome is grey."
            command: Cli.show("kurenai-ctl", ["theme", "type", String(page.th.type || "tonal-spot")])
            Seg {
                width: parent.width
                itemWidth: 108
                model: page.types
                current: page.th.type
                onPicked: v => Cli.run("kurenai-ctl", ["theme", "type", v])
            }
        }
        Line {
            wide: true
            title: "Accent"
            sub: "Wallpaper: the accent follows the image. Vermilion: only the greys follow, the accent stays KURENAI red."
            command: Cli.show("kurenai-ctl", ["theme", "accent", String(page.th.accent || "wallpaper")])
            Seg {
                width: parent.width
                itemWidth: 140
                model: [{ value: "wallpaper", label: "From wallpaper" }, { value: "vermilion", label: "Vermilion" }]
                current: page.th.accent
                onPicked: v => Cli.run("kurenai-ctl", ["theme", "accent", v])
            }
        }
        Line {
            id: cline
            title: "Contrast"
            sub: "-1 is softer, 0 is standard, 1 is stronger."
            command: Cli.show("kurenai-ctl", ["theme", "contrast", String(Number(page.th.contrast || 0))])
            divider: false
            Row {
                id: crow
                spacing: Theme.s3
                property real draft: 0
                readonly property real shown: csettle.running ? draft : Number(page.th.contrast || 0)
                Timer { id: csettle; interval: 500; onTriggered: Cli.run("kurenai-ctl", ["theme", "contrast", crow.draft.toFixed(1)]) }
                KSlider {
                    width: 200
                    anchors.verticalCenter: parent.verticalCenter
                    from: -1; to: 1; step: 0.1
                    value: crow.shown
                    onMoved: v => { crow.draft = Math.round(v * 10) / 10; csettle.restart(); }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: crow.shown.toFixed(1)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsBase
                    color: Theme.text
                }
            }
        }
    }

    Card {
        title: "What follows the wallpaper"
        hint: "The shell and lock screen always follow when this is on. These two are optional."
        Line {
            title: "Hyprland window borders"
            sub: "Active border colour."
            command: Cli.show("kurenai-ctl", ["theme", "hypr", page.th.hypr === false ? "on" : "off"])
            KToggle { checked: page.th.hypr !== false; onToggled: Cli.run("kurenai-ctl", ["theme", "hypr", page.th.hypr === false ? "on" : "off"]) }
        }
        Line {
            title: "Rofi"
            sub: "Writes the colour file the KURENAI Rofi theme reads."
            command: Cli.show("kurenai-ctl", ["theme", "rofi", page.th.rofi === false ? "on" : "off"])
            divider: false
            KToggle { checked: page.th.rofi !== false; onToggled: Cli.run("kurenai-ctl", ["theme", "rofi", page.th.rofi === false ? "on" : "off"]) }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Apps such as kitty, GTK, Qt and Firefox are on the App colours page."
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall + 1
            color: Theme.muted
        }
    }

    Card {
        title: "Colours right now"
        hint: "What this window is using at this moment."
        Flow {
            width: parent.width
            spacing: Theme.s2
            Repeater {
                model: [["background", Theme.bg], ["surface", Theme.surface], ["raised", Theme.raised], ["text", Theme.text], ["muted", Theme.muted],
                        ["accent", Theme.accent], ["accent text", Theme.accentText], ["teal", Theme.teal], ["rose", Theme.rose]]
                Rectangle {
                    required property var modelData
                    width: 96; height: 56
                    radius: Theme.rMd
                    color: modelData[1]
                    border.width: 1
                    border.color: Theme.borderStrong
                    Text {
                        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.s2 }
                        text: modelData[0]
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.contrast(modelData[1], Theme.text) > Theme.contrast(modelData[1], Theme.bg) ? Theme.text : Theme.bg
                    }
                }
            }
        }
    }

    Card {
        title: "Start over"
        Line {
            title: "Back to the built-in colours everywhere"
            sub: "Switches wallpaper colours off, forgets the scheme, accent and contrast, and restores the app colour files."
            command: Cli.show("kurenai-ctl", ["theme", "reset"])
            divider: false
            ConfirmBtn { label: "Reset colours"; onConfirmed: Cli.run("kurenai-ctl", ["theme", "reset"]) }
        }
    }
}
