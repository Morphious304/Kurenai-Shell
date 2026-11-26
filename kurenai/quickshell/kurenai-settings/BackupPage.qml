import QtQuick

Page {
    id: page
    title: "Backup and restore"
    kanji: "備"
    subtitle: "Every change KURENAI makes to hyprland.lua is backed up first. Here you can back up on demand, move your settings between machines, and see where everything lives."

    property var backups: []
    property string exportPath: ""
    property string importPath: ""

    function reload() { Cli.json("kurenai-ctl", ["backups", "--json"], (d, res) => { if (Array.isArray(d)) backups = d; }); }
    Component.onCompleted: reload()
    Connections { target: Cli; function onWrote() { later.restart(); } }
    Timer { id: later; interval: 400; onTriggered: page.reload() }

    Card {
        title: "Config backups"
        hint: "Copies of ~/.config/hypr and ~/.config/quickshell, newest first. “Restore” on the Startup and hooks page uses the latest."
        Line {
            title: "Back up now"
            command: Cli.show("kurenai-ctl", ["backup"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Back up now"; onClicked: Cli.run("kurenai-ctl", ["backup"]) }
        }
        Repeater {
            model: page.backups
            Line {
                id: bk
                required property var modelData
                required property int index
                title: modelData.name
                sub: (modelData.latest ? "Latest. " : "") + (modelData.hypr ? "hypr " : "") + (modelData.quickshell ? "quickshell" : "")
                divider: index < page.backups.length - 1
            }
        }
        Text {
            visible: page.backups.length === 0
            width: parent.width
            text: "No backups yet."
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.muted
        }
    }

    Card {
        title: "Move your settings"
        hint: "Exports only this window's settings and your bind changes (not wallpapers, not secrets) as a small archive. Importing replaces those two files, after checking the archive."
        Line {
            wide: true
            title: "Export to a file"
            command: Cli.show("kurenai-conf", ["export", page.exportPath !== "" ? page.exportPath : "~/kurenai-settings.tar.gz"])
            Row {
                spacing: Theme.s2
                KField { width: 400; mono: true; placeholder: "/home/you/kurenai-settings.tar.gz"; value: page.exportPath; onCommit: t => page.exportPath = t.trim() }
                Btn { width: 100; implicitHeight: 32; center: true; text: "Export"; enabled: page.exportPath !== ""; onClicked: Cli.run("kurenai-conf", ["export", page.exportPath]) }
            }
        }
        Line {
            wide: true
            title: "Import from a file"
            command: Cli.show("kurenai-conf", ["import", page.importPath !== "" ? page.importPath : "~/kurenai-settings.tar.gz"])
            divider: false
            Row {
                spacing: Theme.s2
                KField { width: 400; mono: true; placeholder: "/home/you/kurenai-settings.tar.gz"; value: page.importPath; onCommit: t => page.importPath = t.trim() }
                ConfirmBtn { label: "Import"; implicitWidth: 190; enabled: page.importPath !== ""; onConfirmed: Cli.run("kurenai-conf", ["import", page.importPath]) }
            }
        }
    }

    Card {
        title: "Reset"
        Line {
            title: "Reset every setting in this window to its default"
            sub: "Deletes your saved choices (settings.json). Bind changes and hooks stay as they are."
            command: Cli.show("kurenai-conf", ["reset", "--all"])
            divider: false
            ConfirmBtn { label: "Reset all"; onConfirmed: Store.resetAll() }
        }
    }

    Card {
        title: "Where things live"
        hint: "Copy a path from here to open it in your editor or file manager."
        OutputBox { prog: "kurenai-conf"; args: ["path"]; emptyText: "No paths reported." }
    }
}
