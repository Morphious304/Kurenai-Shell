import QtQuick

// A scrolling page: heading, then whatever you put inside. Content is kept to a readable width.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string kanji: ""
    default property alias content: body.data

    function reveal(item) {
        if (!item) return;
        const y = item.mapToItem(col, 0, 0).y + col.y;
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y - Theme.s6));
    }
    Connections {
        target: App
        function onScrollRequest(item) { root.reveal(item); }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + Theme.s6 * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

    Column {
        id: col
        x: Math.max(Theme.s4, (flick.width - width) / 2)
        y: Theme.s6
        width: Math.min(820, flick.width - Theme.s4 * 2)
        spacing: Theme.s3

        Item {
            width: parent.width
            height: head.implicitHeight + Theme.s2
            Column {
                id: head
                width: parent.width
                spacing: 2
                Row {
                    spacing: Theme.s3
                    Text {
                        visible: root.kanji !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kanji
                        font.family: Theme.fontDisplay
                        font.pixelSize: 26
                        color: Theme.accentText
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.title
                        textFormat: Text.PlainText
                        font.family: Theme.fontUi
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }
                Text {
                    visible: root.subtitle !== ""
                    width: parent.width
                    text: root.subtitle
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                    color: Theme.muted
                }
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.s3
        }
    }

    }

    // thin scroll indicator (the wheel and touchpad scroll; search jumps scroll the row into view)
    Rectangle {
        visible: flick.contentHeight > root.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 3
        width: 4
        radius: 2
        color: Theme.borderStrong
        height: Math.max(24, root.height * root.height / flick.contentHeight)
        y: flick.contentHeight > root.height ? flick.contentY / (flick.contentHeight - root.height) * (root.height - height) : 0
    }
}
