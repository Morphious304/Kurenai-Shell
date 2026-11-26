import QtQuick

Page {
    id: page
    title: "Wallpaper"
    kanji: "壁"
    subtitle: "Pick a wallpaper from your folders. If wallpaper colours are on, the shell and your apps recolour from it."

    property var files: []
    property string current: ""
    property string filter: ""
    property bool scanning: false
    readonly property var shown: {
        const terms = filter.toLowerCase().split(/\s+/).filter(t => t !== "");
        if (terms.length === 0) return files;
        return files.filter(p => { const h = p.toLowerCase(); return terms.every(t => h.indexOf(t) >= 0); });
    }
    readonly property bool awwwOk: Store.tool("awww")

    function rescan() {
        scanning = true;
        Cli.json("kurenai-ctl", ["wallpaper", "list", "--json"], (d, res) => { scanning = false; files = Array.isArray(d) ? d : []; });
        Cli.read("kurenai-ctl", ["wallpaper", "current"], res => { current = res.ok ? res.out.trim() : ""; });
    }
    Component.onCompleted: rescan()
    Connections { target: Cli; function onWrote() { cur.restart(); } }
    Timer { id: cur; interval: 600; onTriggered: Cli.read("kurenai-ctl", ["wallpaper", "current"], res => { page.current = res.ok ? res.out.trim() : ""; }) }

    Card {
        title: "Choose"
        hint: page.awwwOk ? "" : "awww was not found, so a wallpaper cannot be set from here (package: awww). You can still look at your folders."
        Line {
            wide: true
            title: page.files.length + " image" + (page.files.length === 1 ? "" : "s") + " in your wallpaper folders"
            sub: page.scanning ? "Looking..." : "Folders are set below. Click an image to apply it."
            command: Cli.show("kurenai-ctl", ["wallpaper", "set", "/path/to/image"])
            divider: false
            Row {
                spacing: Theme.s2
                KField { width: 300; placeholder: "Filter by file or folder name"; onTextChanged: page.filter = text }
                Btn { width: 100; implicitHeight: 32; center: true; text: "Rescan"; onClicked: page.rescan() }
                Btn { width: 150; implicitHeight: 32; center: true; text: "Recolour from it"; enabled: Store.tool("matugen") && Store.theme().enabled === true
                      onClicked: Cli.run("kurenai-ctl", ["theme", "sync"]) }
            }
        }
        Item {
            width: parent.width
            height: Math.max(1, Math.min(3, Math.ceil(page.shown.length / 3))) * 118 + 4
            clip: true
            GridView {
                id: grid
                anchors.fill: parent
                cellWidth: Math.floor(width / 3)
                cellHeight: 118
                model: page.shown
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 118 * 2
                delegate: Item {
                    id: cell
                    required property string modelData
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCurrent: page.current === modelData
                    Rectangle {
                        anchors { fill: parent; margins: 4 }
                        radius: Theme.rMd
                        color: Theme.bg
                        border.width: cell.isCurrent ? 3 : 1
                        border.color: cell.isCurrent ? Theme.accent : (area.containsMouse ? Theme.borderStrong : Theme.border)
                        clip: true
                        Image {
                            anchors { fill: parent; margins: cell.isCurrent ? 3 : 1 }
                            source: "file://" + cell.modelData
                            sourceSize.width: 360
                            sourceSize.height: 220
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 22
                            color: "#B3141414"
                            Text {
                                anchors { fill: parent; leftMargin: Theme.s2; rightMargin: Theme.s2 }
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideMiddle
                                text: cell.modelData.slice(cell.modelData.lastIndexOf("/") + 1)
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                color: "#F4E8BE"
                            }
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: page.awwwOk
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Cli.run("kurenai-ctl", ["wallpaper", "set", cell.modelData])
                        }
                    }
                }
            }
            Text {
                visible: page.shown.length === 0 && !page.scanning
                anchors.centerIn: parent
                width: parent.width - Theme.s6 * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: page.files.length === 0 ? "No images found. Check the wallpaper folders below." : "No image matches the filter."
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                color: Theme.muted
            }
        }
    }

    SchemaGroup { group: "wallpaper"; title: "Wallpaper settings"; hint: "Where images are looked for, the transition, and how the Walls tab of the launcher looks." }
}
