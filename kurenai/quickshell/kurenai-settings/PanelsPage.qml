import QtQuick

Page {
    id: page
    title: "Bar and panels"
    kanji: "棒"
    subtitle: "Panels, on-screen displays, the system monitor, power and the shortcuts page. The shell picks changes up by itself."

    SchemaGroup { group: "panels"; title: "Panels" }
    SchemaGroup { group: "osd"; title: "On-screen displays (volume, brightness, media)" }
    SchemaGroup { group: "sysmon"; title: "System monitor" }
    SchemaGroup { group: "power"; title: "Power and lock" }
    SchemaGroup { group: "shortcuts"; title: "Shortcuts page" }

    Card {
        title: "Shortcuts page"
        Line {
            title: "Read the Hyprland binds again"
            sub: "Talks to the running shell. Does nothing (and says so) when the shell is stopped."
            command: Cli.show("kurenai-ctl", ["shortcuts", "rescan"])
            divider: false
            Btn { width: 120; implicitHeight: 32; center: true; text: "Rescan"; onClicked: Cli.run("kurenai-ctl", ["shortcuts", "rescan"]) }
        }
    }
}
