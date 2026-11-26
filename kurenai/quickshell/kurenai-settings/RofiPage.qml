import QtQuick

Page {
    id: page
    title: "Rofi"
    kanji: "扉"
    subtitle: "Rofi stays available next to the shell's launcher. This page checks that it uses the KURENAI look."

    readonly property var th: Store.theme()

    Card {
        title: "Rofi theme"
        hint: "Read-only check: is the KURENAI theme installed, is Rofi using it, and how to switch it on."
        OutputBox { args: ["rofi-theme"]; emptyText: "No answer from kurenai-ctl rofi-theme." }
    }

    Card {
        title: "Colours"
        Line {
            title: "Rofi follows the wallpaper colours"
            sub: "Same switch as on the Colours page. Writes the colour file the Rofi theme reads."
            command: Cli.show("kurenai-ctl", ["theme", "rofi", page.th.rofi === false ? "on" : "off"])
            divider: false
            KToggle { checked: page.th.rofi !== false; onToggled: Cli.run("kurenai-ctl", ["theme", "rofi", page.th.rofi === false ? "on" : "off"]) }
        }
    }

    Card {
        title: "Open this window from Rofi"
        hint: "“KURENAI Settings” is an ordinary application entry, so Rofi's drun mode and the launcher list it. It works even when the shell is stopped."
    }
}
