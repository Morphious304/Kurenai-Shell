import QtQuick

Page {
    id: page
    title: "App colours"
    kanji: "彩"
    subtitle: "Colour the apps you use from the same wallpaper palette. Attaching an app makes a backup first and adds ONE marked block to that app's own config."

    readonly property var th: Store.theme()
    readonly property var attached: Array.isArray(th.extras) ? th.extras : []
    readonly property var ff: Store.status.firefox || ({})
    readonly property var apps: [
        { k: "kitty",    name: "kitty",    what: "Terminal colours (a colour file kitty includes)." },
        { k: "gtk",      name: "GTK",      what: "GTK 3 and 4 apps (Files, Firefox's menus, most desktop apps)." },
        { k: "qt",       name: "Qt",       what: "Qt apps, through qt6ct." },
        { k: "btop",     name: "btop",     what: "System monitor theme." },
        { k: "yazi",     name: "yazi",     what: "File manager theme." },
        { k: "zathura",  name: "zathura",  what: "Document viewer colours." },
        { k: "nvim",     name: "Neovim",   what: "A KURENAI colourscheme loaded from your config." },
        { k: "spicetify", name: "Spicetify", what: "Spotify theme (needs Spicetify set up)." },
        { k: "pacsea",   name: "Pacsea",   what: "Package manager TUI colours (your theme.conf is saved and restored)." },
        { k: "lazygit",  name: "lazygit",  what: "Git TUI colours (a gui.theme block in config.yml)." },
        { k: "firefox",  name: "Firefox",  what: "Browser look (CSS layer). Extra options appear below once attached." }
    ]
    function isOn(k) { return attached.indexOf(k) >= 0; }

    Card {
        title: "All apps"
        Line {
            title: "Follow wallpaper changes"
            sub: "On: attached apps recolour whenever the wallpaper changes. Off: they keep their last colours until you press Apply."
            command: Cli.show("kurenai-ctl", ["theme", "extras", "follow", page.th.extrasFollow === false ? "on" : "off"])
            KToggle { checked: page.th.extrasFollow !== false; onToggled: Cli.run("kurenai-ctl", ["theme", "extras", "follow", page.th.extrasFollow === false ? "on" : "off"]) }
        }
        Line {
            title: "Apply the current colours to every attached app"
            command: Cli.show("kurenai-ctl", ["theme", "extras", "apply"])
            Btn { width: 130; implicitHeight: 32; center: true; text: "Apply now"; onClicked: Cli.run("kurenai-ctl", ["theme", "extras", "apply"]) }
        }
        Line {
            title: "Detach every app and restore their own colours"
            sub: "Removes KURENAI's blocks from the apps' configs (backups are kept)."
            command: Cli.show("kurenai-ctl", ["theme", "extras", "reset"])
            divider: false
            ConfirmBtn { label: "Detach all"; onConfirmed: Cli.run("kurenai-ctl", ["theme", "extras", "reset"]) }
        }
    }

    Card {
        title: "Apps"
        Repeater {
            model: page.apps
            Line {
                id: al
                required property var modelData
                title: modelData.name
                sub: modelData.what
                command: Cli.show("kurenai-ctl", ["theme", "extra", modelData.k, page.isOn(modelData.k) ? "off" : "on"])
                divider: modelData.k !== "firefox"
                KToggle {
                    checked: page.isOn(al.modelData.k)
                    onToggled: Cli.run("kurenai-ctl", ["theme", "extra", al.modelData.k, page.isOn(al.modelData.k) ? "off" : "on"])
                }
            }
        }
    }

    Card {
        visible: page.isOn("firefox")
        title: "Firefox options"
        hint: "The CSS layer is already on. These two are optional and need a Firefox restart."
        Line {
            title: "KURENAI start page"
            sub: "A local start page with a clock, search and your tiles. Sets the home page on every Firefox start."
            command: Cli.show("kurenai-ctl", ["theme", "extra", "firefox", "home", page.ff.home === true ? "off" : "on"])
            KToggle { checked: page.ff.home === true; onToggled: Cli.run("kurenai-ctl", ["theme", "extra", "firefox", "home", page.ff.home === true ? "off" : "on"]) }
        }
        Line {
            title: "Script layer (hide/show button, keys, new tab page)"
            sub: "Needs fx-autoconfig. If it is not installed, the command prints exactly what to copy and changes nothing."
            command: Cli.show("kurenai-ctl", ["theme", "extra", "firefox", "script", page.ff.script === true ? "off" : "on"])
            divider: false
            KToggle { checked: page.ff.script === true; onToggled: Cli.run("kurenai-ctl", ["theme", "extra", "firefox", "script", page.ff.script === true ? "off" : "on"]) }
        }
        OutputBox { args: ["theme", "extra", "firefox", "status"]; emptyText: "Firefox status unavailable." }
    }

    Card {
        visible: !page.isOn("firefox")
        title: "Firefox profile"
        hint: "Only needed if KURENAI cannot tell which Firefox profile to use. Set it before attaching Firefox."
        Line {
            wide: true
            title: "Profile folder"
            command: Cli.show("kurenai-ctl", ["theme", "extra", "firefox", "profile", "/path/to/profile"])
            divider: false
            KField {
                width: parent.width
                mono: true
                placeholder: "/home/you/.mozilla/firefox/xxxx.default-release  (about:profiles shows it)"
                onCommit: t => { if (t.trim() !== "") Cli.run("kurenai-ctl", ["theme", "extra", "firefox", "profile", t.trim()]); }
            }
        }
    }
}
