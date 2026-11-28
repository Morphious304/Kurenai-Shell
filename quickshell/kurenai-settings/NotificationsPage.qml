import QtQuick

Page {
    id: page
    title: "Notifications"
    kanji: "知"
    subtitle: "How the shell shows notifications, and which program owns them. Only one program can own them at a time."

    readonly property string owner: String(Store.status.notifier || "")

    SchemaGroup { group: "notifications"; title: "Popups and history" }

    Card {
        title: "Who owns notifications"
        hint: "mako, dunst or swaync may already own them. KURENAI can only show notifications while it does."
        Line {
            title: page.owner !== "" ? "Owned by: " + page.owner : "Nobody owns them right now"
            sub: "Read from the session bus. Refreshes by itself."
            command: Cli.show("kurenai-ctl", ["notif-status"])
            divider: false
            Btn { width: 120; implicitHeight: 32; center: true; text: "Details"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["notif-status"]); } }
        }
        OutputBox { args: ["notif-status"]; emptyText: "No answer from notif-status." }
    }

    Card {
        title: "Nothing pops up?"
        hint: "Sends a low, a normal and a critical test notification and tells you who owns the service. The popups appear top-right, under the bar."
        Line {
            title: "Send test notifications"
            sub: "If another program owns them (mako, dunst, swaync), the answer says so and what to run."
            command: Cli.show("kurenai-ctl", ["notif-test"])
            divider: false
            Btn { width: 120; implicitHeight: 32; center: true; text: "Send test"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["notif-test"]); } }
        }
    }

    Card {
        title: "Switch the owner"
        hint: "Takeover stops the other program (and remembers it). Restore stops the KURENAI shell and starts the previous program again."
        Line {
            title: "Let KURENAI show notifications"
            sub: "Stops the running notification program so the shell can take the service."
            command: Cli.show("kurenai-ctl", ["notif-takeover"])
            ConfirmBtn { label: "Take over"; onConfirmed: Cli.run("kurenai-ctl", ["notif-takeover"]) }
        }
        Line {
            title: "Go back to the previous notification program"
            sub: "Stops the KURENAI shell first, because it would grab the service again."
            command: Cli.show("kurenai-ctl", ["notif-restore"])
            divider: false
            ConfirmBtn { label: "Restore previous"; onConfirmed: Cli.run("kurenai-ctl", ["notif-restore"]) }
        }
    }
}
