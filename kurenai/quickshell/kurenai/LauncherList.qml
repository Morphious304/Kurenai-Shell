import QtQuick
import Quickshell
import Quickshell.Widgets

// The application list used by two launcher tabs (the host is Launcher.qml):
//   mode "apps"  : launch the app normally
//   mode "prime" : launch it through `prime-run`, so it renders on the NVIDIA GPU
// Same contract as the other tab views: query, areaHeight, hint, move(), page(), activate(), star(), expand(), back().
Item {
    id: root

    property string mode: "apps"
    property string query: ""

    readonly property bool isPrime: mode === "prime"
    readonly property bool usable: !isPrime || Apps.primeAvailable
    readonly property var found: usable ? Apps.search(query, mode) : []

    // ---- contract with the host ---------------------------------------------------------------------------------
    readonly property int areaHeight: Math.max(usable && results.count > 0
        ? Math.min(results.count, Config.launcherVisibleRows) * Theme.launcherRowHeight : 96, 96)
    readonly property string hint: isPrime
        ? "↵ run on NVIDIA   ↑↓ move   Ctrl+F favourite   Tab next tab"
        : "↵ launch   ↑↓ move   Ctrl+F favourite   Tab next tab"

    function move(dx, dy) { results.currentIndex = Math.max(0, Math.min(results.count - 1, results.currentIndex + dy)); }
    function page(d)      { move(0, d * Config.launcherVisibleRows); }
    function star() {
        const e = found[results.currentIndex];
        if (e && usable) Apps.toggleFavorite(e.id, mode);
    }
    function expand() {}
    function back() { return false; }          // nothing to close inside this tab
    function reset() { results.currentIndex = 0; }

    function activate(alt) {
        const e = found[results.currentIndex];
        if (!e || !usable) return;
        if (isPrime) Apps.launchPrime(e);
        else Apps.launch(e);
        UiState.launcherOpen = false;
    }

    onQueryChanged: results.currentIndex = 0
    Component.onCompleted: if (isPrime) Apps.checkPrime()

    ListView {
        id: results
        anchors.fill: parent
        clip: true
        visible: root.usable && count > 0
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 90
        currentIndex: 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        model: ScriptModel { values: root.found }

        highlight: Rectangle {
            radius: Theme.rMd
            color: Theme.raised
            Rectangle {      // vermilion selection rule
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

            readonly property bool fav: Apps.isFavorite(modelData.id, root.mode)
            readonly property bool sandboxed: root.isPrime && Apps.isFlatpak(modelData)

            Row {
                anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s3 }
                spacing: Theme.s3

                Item {
                    width: 28
                    height: parent.height
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 26
                        source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon) : ""
                        visible: row.modelData.icon !== ""
                    }
                    Rectangle {      // missing icon: rose initial tile
                        visible: !row.modelData.icon
                        anchors.centerIn: parent
                        width: 26; height: 26
                        radius: Theme.rSm
                        color: Theme.raised
                        Text {
                            anchors.centerIn: parent
                            text: row.modelData.name.charAt(0).toUpperCase()
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase
                            font.weight: Font.Bold
                            color: Theme.rose
                        }
                    }
                }

                Column {
                    width: parent.width - 28 - Theme.s3 * 2 - (root.isPrime ? 56 : 18)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 1
                        font.weight: Font.Medium
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: row.sandboxed ? "Flatpak: prime-run may not reach the sandbox"
                                            : (row.modelData.genericName || row.modelData.comment || "")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: row.sandboxed ? Theme.amber : Theme.teal
                    }
                }

                Item {      // right edge: NVIDIA marker (Prime tab) + favourite star
                    width: root.isPrime ? 56 : 18
                    height: parent.height

                    Rectangle {
                        visible: root.isPrime
                        anchors { right: favStar.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                        width: 26; height: 16
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.teal
                        Text {
                            anchors.centerIn: parent
                            text: "NV"
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.teal
                        }
                    }
                    Text {
                        id: favStar
                        width: 18
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        horizontalAlignment: Text.AlignRight
                        visible: row.fav
                        text: Theme.icons.star
                        font.family: Theme.fontIcon
                        font.pixelSize: 12
                        color: Theme.amber
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

    // ---- empty / unavailable states ---------------------------------------------------------------------------
    Column {
        visible: root.usable && results.count === 0
        anchors.centerIn: parent
        spacing: Theme.s1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No applications match “" + root.query.trim() + "”"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - Theme.s6)
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.text2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Apps.all.length === 0 ? "No desktop entries found on this system." : "Check the spelling, or try the Rofi fallback."
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
    }

    Column {
        visible: !root.usable && Apps.primeChecked
        anchors.centerIn: parent
        spacing: Theme.s1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "“" + Config.primeCommand + "” was not found"
            textFormat: Text.PlainText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.text2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "On Arch it comes with the nvidia-prime package. Reopen this tab after installing."
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
    }
}
