import QtQuick

// A labelled meter: caption on the left, the number on the right, a bar underneath, an optional detail line.
// The NUMBER is always shown; colour only reinforces it.
//   default      teal normal, amber getting full (70%), vermilion nearly full (90%)   (CPU, memory, temperature, storage)
//   lowIsBad     the reverse, for a battery: teal normal, amber at 30% or less, vermilion at 15% or less
Column {
    id: root

    property string label: ""
    property string value: ""
    property real fraction: -1            // 0..1, or -1 = no bar
    property string detail: ""
    property bool lowIsBad: false         // true = "empty is the problem" (battery) instead of "full is the problem"

    spacing: 5

    Item {
        width: root.width
        height: 18
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: root.label
            textFormat: Text.PlainText
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.letterSpacing: 0.5
            color: Theme.muted
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.value
            textFormat: Text.PlainText
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsBase
            color: Theme.text
        }
    }

    Rectangle {
        visible: root.fraction >= 0
        width: root.width
        height: 6
        radius: 3
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong
        Rectangle {
            width: Math.max(0, Math.min(1, root.fraction)) * parent.width
            height: parent.height
            radius: 3
            color: root.lowIsBad
                   ? (root.fraction <= 0.15 ? Theme.accent : root.fraction <= 0.30 ? Theme.amber : Theme.teal)
                   : (root.fraction < 0.7 ? Theme.teal : root.fraction < 0.9 ? Theme.amber : Theme.accent)
            Behavior on width { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        visible: root.detail !== ""
        width: root.width
        text: root.detail
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
        color: Theme.muted
    }
}
