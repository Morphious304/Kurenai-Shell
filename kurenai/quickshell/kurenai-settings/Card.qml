import QtQuick

// A titled panel. Put rows inside.
Rectangle {
    id: root

    property string title: ""
    property string hint: ""
    default property alias content: col.data

    width: parent ? parent.width : 400
    implicitHeight: col.implicitHeight + Theme.s4 * 2
    height: implicitHeight
    radius: Theme.rLg
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    Column {
        id: col
        x: Theme.s4
        y: Theme.s4
        width: root.width - Theme.s4 * 2
        spacing: Theme.s2

        Text {
            visible: root.title !== ""
            width: parent.width
            text: root.title
            textFormat: Text.PlainText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase + 2
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall + 1
            color: Theme.muted
        }
    }
}
