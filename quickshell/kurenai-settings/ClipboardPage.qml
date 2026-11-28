import QtQuick

Page {
    id: page
    title: "Clipboard"
    kanji: "貼"
    subtitle: "Clipboard history is kept only on this computer, in private files. Pause it before copying a password if you want to be sure."

    property int purgeDays: 30

    SchemaGroup { group: "clipboard"; title: "Panel" }

    Card {
        title: "Recording"
        OutputBox { args: ["clip-status"]; emptyText: "No answer from clip-status." }
        Line {
            title: "Pause recording"
            sub: "Nothing copied while paused is stored."
            command: Cli.show("kurenai-clip", ["pause"])
            Row {
                spacing: Theme.s2
                Btn { width: 100; implicitHeight: 32; center: true; text: "Pause"; onClicked: Cli.run("kurenai-clip", ["pause"]) }
                Btn { width: 100; implicitHeight: 32; center: true; text: "Resume"; onClicked: Cli.run("kurenai-clip", ["resume"]) }
            }
        }
        Line {
            title: "Delete old entries"
            sub: "Removes entries older than this many days. Pinned items stay."
            command: Cli.show("kurenai-clip", ["purge", String(page.purgeDays)])
            divider: false
            Row {
                spacing: Theme.s2
                KField { width: 70; mono: true; numeric: true; value: String(page.purgeDays)
                         onCommit: t => { const n = Math.round(Number(t)); if (n >= 1 && n <= 3650) page.purgeDays = n; else text = String(page.purgeDays); } }
                ConfirmBtn { label: "Purge"; implicitWidth: 190; onConfirmed: Cli.run("kurenai-clip", ["purge", String(page.purgeDays)]) }
            }
        }
    }

    Card {
        title: "Pins"
        hint: "Pinned items survive wipes and purges. Pin and unpin single items in the clipboard panel."
        OutputBox { prog: "kurenai-clip"; args: ["pins"]; emptyText: "No pinned items." }
        Line {
            title: "Unpin everything"
            command: Cli.show("kurenai-clip", ["unpin-all"])
            divider: false
            ConfirmBtn { label: "Unpin all"; onConfirmed: Cli.run("kurenai-clip", ["unpin-all"]) }
        }
    }

    Card {
        title: "Delete the history"
        Line {
            title: "Wipe the whole clipboard history"
            sub: "Everything except pinned items. This cannot be undone."
            command: Cli.show("kurenai-clip", ["wipe"])
            divider: false
            ConfirmBtn { label: "Wipe history"; onConfirmed: Cli.run("kurenai-clip", ["wipe"]) }
        }
    }
}
