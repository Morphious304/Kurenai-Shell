import QtQuick

Page {
    id: page
    title: "Startup and hooks"
    kanji: "連"
    subtitle: "KURENAI joins Hyprland through a few single, marked lines in hyprland.lua. Each one can be switched on and off here; a backup is made first."

    readonly property var hooks: [
        { k: "autostart", name: "Start the shell with the session", on: "enable-autostart", off: "disable-autostart",
          what: "Runs the KURENAI shell when you log in." },
        { k: "binds", name: "Keybinds", on: "enable-binds", off: "disable-binds",
          what: "Loads KURENAI's keys. Use binds-check on the Keybinds page first." },
        { k: "theme", name: "Look (borders, gaps, rounding, motion)", on: "enable", off: "disable",
          what: "Loads the KURENAI Hyprland look." },
        { k: "lock", name: "Lock screen process", on: "enable-lock", off: "disable-lock",
          what: "Starts the locker with the session and makes Hyprland restart it after a crash." },
        { k: "hypr", name: "Monitors and input", on: "enable-hypr", off: "disable-hypr",
          what: "Loads what the Display and input page generates. Switched on by its Apply button." },
        { k: "glass", name: "Glass (hyprglass plugin)", on: "enable-glass", off: "disable-glass",
          what: "Loads the hyprglass plugin at every start and applies the KURENAI glass settings. Needs the plugin installed once: hyprpm add https://github.com/hyprnux/hyprglass, then hyprpm enable hyprglass. Check: kurenai-ctl glass-status." }
    ]

    Card {
        title: "Hooks"
        Repeater {
            model: page.hooks
            Line {
                id: hl
                required property var modelData
                required property int index
                readonly property bool on: Store.hook(modelData.k)
                title: modelData.name
                sub: modelData.what
                command: Cli.show("kurenai-ctl", [on ? modelData.off : modelData.on])
                divider: index < page.hooks.length - 1
                KToggle { checked: hl.on; onToggled: Cli.run("kurenai-ctl", [hl.on ? hl.modelData.off : hl.modelData.on]) }
            }
        }
    }

    Card {
        title: "Undo everything"
        hint: "Rollback removes every hook, stops the shell, brings back the previous notification program and moves KURENAI's files aside. Restore does the same and also puts back hyprland.lua from the latest backup."
        Line {
            title: "Rollback"
            command: Cli.show("kurenai-ctl", ["rollback"])
            ConfirmBtn { label: "Roll back"; onConfirmed: Cli.run("kurenai-ctl", ["rollback"]) }
        }
        Line {
            title: "Restore the latest backup"
            command: Cli.show("kurenai-ctl", ["restore"])
            divider: false
            ConfirmBtn { label: "Restore backup"; onConfirmed: Cli.run("kurenai-ctl", ["restore"]) }
        }
    }
}
