import QtQuick
import Quickshell

// The Walls tab: a grid of thumbnails of every wallpaper under Config.wallpaperDirs.
//   * the grid is virtual: only the cells on screen exist, and a cell decodes its thumbnail only after it has
//     stayed on screen for Config.wallpaperThumbDelay ms, so flicking through hundreds of files stays cheap
//   * moving the selection never changes your wallpaper. Enter sets it (awww, see Walls.qml),
//     Shift+Enter sets it and keeps the launcher open, Ctrl+E (or Space on an empty search) shows a big preview
// Same contract as the other tab views: query, areaHeight, hint, move(), page(), activate(), star(), expand(), back().
Item {
    id: root

    property string query: ""

    readonly property var shown: Walls.filter(query)
    readonly property int cols: Math.max(1, Config.wallpaperColumns)
    readonly property real cellW: Math.floor(width / cols)
    readonly property real thumbH: Math.round((cellW - 8) * 9 / 16)
    readonly property real cellH: thumbH + 8 + 22
    readonly property int infoH: 26
    readonly property int areaHeight: Math.round(cellH * Config.wallpaperVisibleRows) + infoH
    property bool previewing: false
    property bool touched: false         // once you move or type, the selection stops jumping to the current wallpaper

    readonly property var selected: shown[grid.currentIndex] || null
    readonly property string hint: previewing
        ? "↵ apply   Esc back   Ctrl+E close preview"
        : "↵ set   ⇧↵ set and stay   Ctrl+E preview   ←↑↓→ move"

    function move(dx, dy) {
        if (grid.count === 0) return;
        touched = true;
        grid.currentIndex = Math.max(0, Math.min(grid.count - 1, grid.currentIndex + dx + dy * cols));
    }
    function page(d) { move(0, d * Config.wallpaperVisibleRows); }
    function star() {}
    function expand() { if (selected) previewing = !previewing; }
    function reset() { previewing = false; touched = false; grid.currentIndex = 0; selectCurrent(); Walls.open(); }

    // Esc closes the preview first; only then the launcher itself
    function back() {
        if (previewing) { previewing = false; return true; }
        return false;
    }

    // Space on an empty search opens the preview (otherwise it is just a space in the filter)
    function spaceKey() {
        if (query !== "" || !selected) return false;
        previewing = !previewing;
        return true;
    }

    function activate(alt) {
        const s = selected;
        if (!s) return;
        Walls.apply(s.path);
        if (alt !== true) UiState.launcherOpen = false;
    }

    // start on the wallpaper that is on screen now
    function selectCurrent() {
        for (let i = 0; i < shown.length; i++) {
            if (Walls.isCurrent(shown[i].path)) { grid.currentIndex = i; grid.positionViewAtIndex(i, GridView.Center); return; }
        }
    }

    onQueryChanged: { touched = true; grid.currentIndex = 0; previewing = false; }
    onShownChanged: if (!touched && query === "") Qt.callLater(root.selectCurrent)
    Connections {
        target: Walls
        function onCurrentPathsChanged() { if (!root.touched && !root.previewing) root.selectCurrent(); }
    }
    Component.onCompleted: { Walls.open(); }

    // ---- grid ---------------------------------------------------------------------------------------------------
    GridView {
        id: grid
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.cellH * Config.wallpaperVisibleRows
        visible: count > 0 && !root.previewing
        clip: true
        cellWidth: root.cellW
        cellHeight: root.cellH
        cacheBuffer: root.cellH          // keep one extra row alive, no more
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: 0
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        model: ScriptModel { values: root.shown }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool isSel: GridView.isCurrentItem
            readonly property bool isNow: Walls.isCurrent(modelData.path)
            property bool ready: false          // flips after the debounce; only then is the image decoded

            Timer {
                interval: Config.wallpaperThumbDelay
                running: true
                onTriggered: cell.ready = true
            }

            Rectangle {      // the thumbnail frame
                id: frame
                x: 4; y: 4
                width: parent.width - 8
                height: root.thumbH
                radius: Theme.rMd
                color: Theme.surface
                border.width: cell.isSel ? 2 : 1
                border.color: cell.isSel ? Theme.accent : Theme.border
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: cell.ready ? "file://" + encodeURI(cell.modelData.path) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: Math.round(root.cellW * 2)     // decode small: about 2x the cell, whatever the file size
                    smooth: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
                }

                Text {       // not decoded yet / unreadable
                    anchors.centerIn: parent
                    visible: !cell.ready
                    text: Theme.icons.search
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fsIcon
                    color: Theme.border
                }

                Rectangle {      // "GIF" badge: the thumbnail is the first frame
                    visible: cell.modelData.gif
                    anchors { left: parent.left; bottom: parent.bottom; margins: 5 }
                    width: gifText.implicitWidth + 8
                    height: 15
                    radius: 4
                    color: Theme.panelBg
                    Text {
                        id: gifText
                        anchors.centerIn: parent
                        text: "GIF"
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Theme.rose
                    }
                }

                Rectangle {      // "on screen now" tick
                    visible: cell.isNow
                    anchors { right: parent.right; top: parent.top; margins: 5 }
                    width: 18; height: 18
                    radius: 9
                    color: Theme.teal
                    Text {
                        anchors.centerIn: parent
                        text: Theme.icons.check
                        font.family: Theme.fontIcon
                        font.pixelSize: 10
                        color: Theme.inkOnAccent
                    }
                }
            }

            Text {
                anchors { left: frame.left; right: frame.right; top: frame.bottom; topMargin: 3 }
                text: cell.modelData.name.replace(/\.[^.]+$/, "")
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                color: cell.isSel ? Theme.text : Theme.muted
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.touched = true;
                    if (grid.currentIndex === cell.index) root.activate(false);
                    else grid.currentIndex = cell.index;     // first click selects, second click (or Enter) sets
                }
            }
        }
    }

    // ---- big preview ------------------------------------------------------------------------------------------------
    Rectangle {
        id: preview
        visible: root.previewing && root.selected !== null
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
        height: root.cellH * Config.wallpaperVisibleRows - 8
        radius: Theme.rMd
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong
        clip: true

        // a plain Image for stills; animated GIFs play in the preview (switch off: Config.wallpaperAnimatePreview)
        readonly property bool animated: Config.wallpaperAnimatePreview && root.selected !== null && root.selected.gif
        readonly property string url: root.selected ? "file://" + encodeURI(root.selected.path) : ""

        Loader {
            anchors.fill: parent
            anchors.margins: 1
            active: preview.visible
            sourceComponent: preview.animated ? animC : stillC
        }
        Component {
            id: stillC
            Image {
                source: preview.url
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.round(root.width * 2)
            }
        }
        Component {
            id: animC
            AnimatedImage {
                source: preview.url
                asynchronous: true
                playing: true
                fillMode: Image.PreserveAspectFit
            }
        }
        MouseArea { anchors.fill: parent; onClicked: root.previewing = false }
    }

    // ---- empty states ---------------------------------------------------------------------------------------------------
    Column {
        visible: grid.count === 0
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -root.infoH / 2 }
        spacing: Theme.s1
        width: parent.width - Theme.s6
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Walls.scanning ? "Looking for wallpapers..."
                : root.query.trim() !== "" && Walls.files.length > 0 ? "No wallpaper matches “" + root.query.trim() + "”"
                : "No wallpapers found"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.text2
        }
        Text {
            width: parent.width
            visible: !Walls.scanning && Walls.files.length === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Walls.scanNote
            textFormat: Text.PlainText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
    }

    // ---- info line: where this file is, how many there are, what just happened ------------------------------------------
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Theme.s2; rightMargin: Theme.s2 }
        height: root.infoH

        Text {
            anchors { left: parent.left; right: counter.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
            text: Walls.status !== "" ? Walls.status : (root.selected ? root.selected.rel : "")
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall - 1
            color: Walls.status === "" ? Theme.muted : Walls.statusIsError ? Theme.amber : Theme.teal
        }
        Text {
            id: counter
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: grid.count > 0
            text: (grid.currentIndex + 1) + " / " + grid.count
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall - 1
            color: Theme.muted
        }
    }
}
