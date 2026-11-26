import QtQuick

Page {
    id: page
    title: "Launcher"
    kanji: "起"
    subtitle: "The shell's launcher (Super+Space): how it behaves, your favourites, and what it remembers."

    SchemaGroup { group: "launcher"; title: "Behaviour" }

    FavList { title: "Favourites"; hint: "Shown first when the search box is empty. Order matters."; prime: false }
    FavList { title: "Prime favourites"; hint: "The Prime tab runs apps on the NVIDIA GPU through the Prime wrapper. It keeps its own list."; prime: true }

    Card {
        title: "Remembered"
        Line {
            title: "Recent apps"
            command: Cli.show("kurenai-conf", ["recent", "clear"])
            Btn { width: 100; implicitHeight: 32; center: true; text: "Clear"; onClicked: Cli.run("kurenai-conf", ["recent", "clear"]) }
        }
        Line {
            title: "Recent Prime apps"
            command: Cli.show("kurenai-conf", ["recent", "clear", "--prime"])
            Btn { width: 100; implicitHeight: 32; center: true; text: "Clear"; onClicked: Cli.run("kurenai-conf", ["recent", "clear", "--prime"]) }
        }
        Line {
            title: "Forget everything"
            sub: "Favourites, recents, Prime favourites and the Run command history."
            command: Cli.show("kurenai-ctl", ["reset-launcher"])
            divider: false
            ConfirmBtn { label: "Reset launcher"; onConfirmed: Cli.run("kurenai-ctl", ["reset-launcher"]) }
        }
    }
}
