import QtQuick

// The Output drawer: every command this window ran, exactly as you could type it, and what it printed.
Rectangle {
    id: root

    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    Item {
        id: head
        x: Theme.s3; y: Theme.s2
        width: parent.width - Theme.s3 * 2
        height: 32
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Output"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            anchors.centerIn: parent
            text: "what this window ran, and what it said"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.s1
            Btn { width: 70; implicitHeight: 28; height: 28; center: true; text: "Clear"; onClicked: Cli.clearLog() }
            Btn { width: 70; implicitHeight: 28; height: 28; center: true; text: "Close"; onClicked: App.drawerOpen = false }
        }
    }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: Theme.s3; topMargin: Theme.s1 }
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)     // follow the newest line

        Column {
            id: col
            width: flick.width
            spacing: Theme.s2

            Text {
                visible: Cli.log.length === 0
                text: "Nothing yet. Changes and checks you run from this window appear here."
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall + 1
                color: Theme.muted
            }
            Repeater {
                model: Cli.log
                Column {
                    id: entry
                    required property var modelData
                    width: col.width
                    spacing: 2
                    Row {
                        spacing: Theme.s2
                        Text {
                            text: entry.modelData.time
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsSmall
                            color: Theme.muted
                        }
                        Text {
                            text: entry.modelData.state === "running" ? "running..." : entry.modelData.state === "failed" ? "failed" : entry.modelData.state === "started" ? "started" : "ok"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsSmall
                            color: entry.modelData.state === "failed" ? Theme.amber : entry.modelData.state === "running" ? Theme.muted : Theme.teal
                        }
                    }
                    TextEdit {
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: "$ " + entry.modelData.cmd
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall + 1
                        font.weight: Font.Medium
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.inkOnAccent
                    }
                    TextEdit {
                        visible: entry.modelData.out !== ""
                        width: parent.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: entry.modelData.out
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall
                        color: Theme.text2
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.inkOnAccent
                    }
                }
            }
        }
    }
}
