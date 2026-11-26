import QtQuick
import Quickshell

// The Run tab: row 0 is exactly what you typed (Enter runs it), the rows below are your recent commands and
// programs found on $PATH. See Runner.qml for what is stored and how commands are started.
// Same contract as the other tab views: query, areaHeight, hint, move(), page(), activate(), star(), expand(), back().
Item {
    id: root

    property string query: ""

    readonly property var rows: Runner.suggest(query)
    readonly property int areaHeight: Math.max(results.count > 0
        ? Math.min(results.count, Config.launcherVisibleRows) * Theme.launcherRowHeight : 96, 96)
    readonly property string hint: "↵ run   ⇧↵ in terminal   Ctrl+E edit   Ctrl+F forget   Tab next tab"

    function move(dx, dy) { results.currentIndex = Math.max(0, Math.min(results.count - 1, results.currentIndex + dy)); }
    function page(d)      { move(0, d * Config.launcherVisibleRows); }
    function back() { return false; }
    function reset() { results.currentIndex = 0; }

    // Enter / Shift+Enter. `alt` = run in the terminal. The typed text decides whether it is remembered
    // (a leading space = private), so the host hands it to us as `rawQuery`.
    property string rawQuery: query
    function activate(alt) {
        const r = rows[results.currentIndex];
        if (!r) return;
        Runner.run(r.cmd, alt === true, r.kind === "literal" ? rawQuery : r.cmd);
        UiState.launcherOpen = false;
    }

    // Ctrl+F: forget the highlighted history entry
    function star() {
        const r = rows[results.currentIndex];
        if (r && r.kind === "history") Runner.forget(r.cmd);
    }

    // Ctrl+E: put the highlighted row into the search field so you can change it before running
    signal editRequested(string text)
    function expand() {
        const r = rows[results.currentIndex];
        if (r) editRequested(r.cmd);
    }

    onQueryChanged: results.currentIndex = 0
    Component.onCompleted: Runner.refreshIndex()

    ListView {
        id: results
        anchors.fill: parent
        clip: true
        visible: count > 0
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 90
        currentIndex: 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        model: ScriptModel { values: root.rows }

        highlight: Rectangle {
            radius: Theme.rMd
            color: Theme.raised
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                width: 3
                radius: 1.5
                color: Theme.accent
            }
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            width: results.width
            height: Theme.launcherRowHeight

            Row {
                anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s3 }
                spacing: Theme.s3

                Item {
                    width: 28
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26
                        radius: Theme.rSm
                        color: Theme.raised
                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.kind === "history" ? Theme.icons.clock : "$"
                            font.family: row.modelData.kind === "history" ? Theme.fontIcon : Theme.fontMono
                            font.pixelSize: row.modelData.kind === "history" ? 12 : Theme.fsBase
                            font.weight: Font.Bold
                            color: row.modelData.kind === "literal" ? Theme.accentText
                                 : row.modelData.kind === "history" ? Theme.teal : Theme.rose
                        }
                    }
                }

                Column {
                    width: parent.width - 28 - Theme.s3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.cmd
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsBase
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.kind === "literal" ? "Run in a shell (sh -c)"
                            : row.modelData.kind === "history" ? "From your history"
                            : "Program on your PATH"
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: results.currentIndex = row.index
                onClicked: { results.currentIndex = row.index; root.activate(false); }
            }
        }
    }

    Column {
        visible: results.count === 0
        anchors.centerIn: parent
        spacing: Theme.s1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Type a command and press Enter"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.text2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.runHistory ? "Commands you run appear here. Start with a space to keep one private."
                                    : "History is off (Config.runHistory)."
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
    }
}
