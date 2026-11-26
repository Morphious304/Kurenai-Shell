import QtQuick

// Favourites (or Prime favourites) of the launcher, through `kurenai-conf fav ...`.
Card {
    id: root

    property bool prime: false
    property var ids: []
    property string query: ""
    readonly property var extra: root.prime ? ["--prime"] : []

    function reload() { Cli.json("kurenai-conf", ["fav", "list", "--json"].concat(extra), (d, res) => { if (Array.isArray(d)) ids = d; }); }
    Component.onCompleted: reload()
    Connections { target: Cli; function onWrote() { later.restart(); } }
    Timer { id: later; interval: 300; onTriggered: root.reload() }

    function add(id) { Cli.run("kurenai-conf", ["fav", "add", id].concat(extra)); query = ""; finder.text = ""; }

    Repeater {
        model: root.ids
        Line {
            id: fl
            required property var modelData
            required property int index
            title: AppIndex.nameOf(modelData)
            sub: modelData
            command: Cli.show("kurenai-conf", ["fav", "remove", modelData].concat(root.extra))
            divider: index < root.ids.length - 1
            Row {
                spacing: Theme.s1
                Btn { width: 34; height: 30; implicitHeight: 30; center: true; icon: Theme.icons.chevUp; enabled: fl.index > 0
                      onClicked: Cli.run("kurenai-conf", ["fav", "move", fl.modelData, "up"].concat(root.extra)) }
                Btn { width: 34; height: 30; implicitHeight: 30; center: true; icon: Theme.icons.chevDown; enabled: fl.index < root.ids.length - 1
                      onClicked: Cli.run("kurenai-conf", ["fav", "move", fl.modelData, "down"].concat(root.extra)) }
                Btn { width: 64; height: 30; implicitHeight: 30; center: true; text: "Top"; enabled: fl.index > 0
                      onClicked: Cli.run("kurenai-conf", ["fav", "move", fl.modelData, "top"].concat(root.extra)) }
                Btn { width: 84; height: 30; implicitHeight: 30; center: true; text: "Remove"
                      onClicked: Cli.run("kurenai-conf", ["fav", "remove", fl.modelData].concat(root.extra)) }
            }
        }
    }
    Text {
        visible: root.ids.length === 0
        width: parent.width
        text: root.prime ? "No Prime favourites yet." : "No favourites yet. Add one below, or press Ctrl+P on an app in the launcher."
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBase
        color: Theme.muted
    }

    KField {
        id: finder
        width: parent.width
        placeholder: "Find an installed app to add"
        onCommit: t => { const r = AppIndex.find(t, 1); if (r.length > 0) root.add(r[0].id); }
        onTextChanged: root.query = text
    }
    Repeater {
        model: AppIndex.find(root.query, 6)
        Btn {
            required property var modelData
            width: parent.width
            icon: ""
            text: modelData.name
            subtext: modelData.id
            onClicked: root.add(modelData.id)
        }
    }
}
