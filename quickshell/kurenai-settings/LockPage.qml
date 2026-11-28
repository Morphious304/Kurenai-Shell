import QtQuick

Page {
    id: page
    title: "Lock screen"
    kanji: "鎖"
    subtitle: "Settings for the lock screen, and the tools to test it safely. A wrong lock screen can lock you out, so every risky step asks first."

    readonly property var lk: Store.status.lock || ({})
    readonly property bool up: lk.running === true

    Card {
        title: "State"
        Line {
            title: page.up ? "The lock process is running" : "The lock process is not running"
            sub: page.lk.state ? "State: " + page.lk.state : "It starts with the session when the Lock hook is on (Startup and hooks)."
            command: Cli.show("kurenai-ctl", ["lock-status"])
            Row {
                spacing: Theme.s2
                Btn { width: 84; implicitHeight: 32; center: true; text: "Start"; enabled: !page.up; onClicked: Cli.run("kurenai-ctl", ["lock-start"]) }
                Btn { width: 84; implicitHeight: 32; center: true; text: "Stop"; enabled: page.up; onClicked: Cli.run("kurenai-ctl", ["lock-stop"]) }
            }
        }
        Line {
            title: "Look at it without locking anything"
            sub: "Opens the lock screen in a normal window with the real password check. Close the window to leave."
            command: Cli.show("kurenai-ctl", ["lock-preview"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Preview"; onClicked: Cli.detach("kurenai-ctl", ["lock-preview"]) }
        }
        Line {
            title: "Lock the screen now"
            command: Cli.show("kurenai-ctl", ["lock"])
            divider: false
            ConfirmBtn { label: "Lock now"; implicitWidth: 190; onConfirmed: Cli.run("kurenai-ctl", ["lock"]) }
        }
    }

    SchemaGroup { group: "lock"; title: "Lock screen settings"; hint: "Read the next time the lock process starts (use Restart below)." }

    Card {
        title: "Apply and repair"
        Line {
            title: "Restart the lock process"
            sub: "Picks up the settings above. Refused while the screen is locked."
            command: Cli.show("kurenai-ctl", ["lock-stop"]) + "  &&  " + Cli.show("kurenai-ctl", ["lock-start"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Restart"
                  onClicked: Cli.run("kurenai-ctl", ["lock-stop"], r => Cli.run("kurenai-ctl", ["lock-start"])) }
        }
        Line {
            title: "Copy the shell's theme into the lock screen"
            sub: "Use after you edit the theme by hand."
            command: Cli.show("kurenai-ctl", ["lock-sync-theme"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Sync theme"; onClicked: Cli.run("kurenai-ctl", ["lock-sync-theme"]) }
        }
        Line {
            title: "The screen says locked but I am on my desktop"
            sub: "Clean restart of the locker."
            command: Cli.show("kurenai-ctl", ["lock-reset"])
            ConfirmBtn { label: "Reset lock"; onConfirmed: Cli.run("kurenai-ctl", ["lock-reset"]) }
        }
        Line {
            title: "If you are ever stuck on a grey or empty lock screen"
            sub: "Press Ctrl+Alt+F3, log in, and run: kurenai-ctl lock-recover"
            divider: false
        }
    }

    Card {
        title: "Reports"
        hint: "Read-only. Results appear in the Output drawer."
        Line {
            title: "Diagnose"
            sub: "One compact report for troubleshooting (no passwords)."
            command: Cli.show("kurenai-ctl", ["lock-diagnose"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Diagnose"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["lock-diagnose"]); } }
        }
        Line {
            title: "Idle and sleep (hypridle)"
            sub: "The settings that lock after idle and before sleep. Shown, never changed."
            command: Cli.show("kurenai-ctl", ["lock-hypridle"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Show"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["lock-hypridle"]); } }
        }
        Line {
            title: "Stronger password check (root-owned PAM service)"
            sub: "Prints the steps. They need sudo, so this window never runs them."
            command: Cli.show("kurenai-ctl", ["lock-harden"])
            divider: false
            Btn { width: 130; implicitHeight: 32; center: true; text: "Show steps"; onClicked: { App.drawerOpen = true; Cli.run("kurenai-ctl", ["lock-harden"]); } }
        }
    }
}
