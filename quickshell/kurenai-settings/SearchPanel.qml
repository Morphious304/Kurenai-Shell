import QtQuick

// Search results over the page (Ctrl+K). Settings and pages; Enter opens the first result, Up/Down move, Esc closes.
Rectangle {
    id: root

    property var results: App.search(App.query)
    property int index: 0
    signal closed()

    color: Theme.surface
    border.width: 1
    border.color: Theme.panelBorder
    radius: Theme.rLg

    onResultsChanged: index = 0

    function open(i) {
        const r = results[i === undefined ? index : i];
        if (r) App.go(r.page, r.key);
    }
    function move(d) { index = Math.max(0, Math.min(results.length - 1, index + d)); list.positionViewAtIndex(index, ListView.Contain); }

    Text {
        visible: root.results.length === 0
        anchors.centerIn: parent
        text: "Nothing matches “" + App.query + "”"
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBase
        color: Theme.muted
    }

    ListView {
        id: list
        anchors { fill: parent; margins: Theme.s2 }
        clip: true
        model: root.results
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        delegate: Btn {
            required property var modelData
            required property int index
            width: list.width
            icon: modelData.kind === "page" ? "" : ""
            text: modelData.title
            subtext: modelData.sub
            checked: index === root.index
            onClicked: root.open(index)
        }
    }
}
