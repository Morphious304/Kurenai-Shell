import QtQuick

// One row: title and explanation on the left, the control(s) on the right (or underneath when `wide`),
// and a "Show command" line that prints exactly what the control runs, so nothing is a black box.
Item {
    id: root

    property string title: ""
    property string sub: ""
    property string command: ""          // shown under "Show command"; empty = no such link
    property bool wide: false            // controls go under the text, full width
    property bool changed: false         // setting differs from its default
    property string defaultText: ""
    property bool highlighted: false     // arrived from the search box
    property bool divider: true
    property bool cmdOpen: false
    signal resetClicked()

    default property alias controls: ctl.data

    readonly property int pad: Theme.s2
    readonly property real topH: wide ? txt.height + (ctl.height > 0 ? Theme.s2 + ctl.height : 0)
                                      : Math.max(txt.height, ctl.height)

    width: parent ? parent.width : 400
    implicitHeight: Math.max(40, topH + pad * 2 + (cmdOpen && command !== "" ? cmdBox.height + Theme.s1 : 0))
    height: implicitHeight

    Rectangle {
        anchors { fill: parent; leftMargin: -2; rightMargin: -2 }
        radius: Theme.rMd
        color: root.highlighted ? Theme.alpha(Theme.teal, 0.12) : "transparent"
        border.width: root.highlighted ? 2 : 0
        border.color: Theme.teal
    }

    Column {
        id: txt
        x: Theme.s2
        y: root.pad
        width: root.wide ? root.width - Theme.s2 * 2 : Math.max(140, root.width - ctl.width - Theme.s2 * 3)
        spacing: 2

        Row {
            spacing: Theme.s2
            Text {
                id: titleText
                text: root.title
                textFormat: Text.PlainText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                font.weight: Font.Medium
                color: Theme.text
            }
            Rectangle {
                visible: root.changed
                anchors.verticalCenter: parent.verticalCenter
                width: chg.implicitWidth + Theme.s2 * 2
                height: 16
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: Theme.accentText
                Text {
                    id: chg
                    anchors.centerIn: parent
                    text: "changed"
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall - 1
                    color: Theme.accentText
                }
            }
            Btn {
                visible: root.changed
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                width: 64
                implicitHeight: 22
                center: true
                flat: true
                text: "Reset"
                onClicked: root.resetClicked()
            }
        }
        Text {
            visible: root.sub !== ""
            width: parent.width
            text: root.sub + (root.changed && root.defaultText !== "" ? "  (default: " + root.defaultText + ")" : "")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall + 1
            color: Theme.muted
        }
        Text {
            visible: root.command !== ""
            text: root.cmdOpen ? "Hide command" : "Show command"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.underline: true
            color: showArea.containsMouse ? Theme.text : Theme.muted
            MouseArea {
                id: showArea
                anchors { fill: parent; margins: -4 }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cmdOpen = !root.cmdOpen
            }
        }
    }

    Item {
        id: ctl
        width: root.wide ? root.width - Theme.s2 * 2 : childrenRect.width
        height: childrenRect.height
        x: root.wide ? Theme.s2 : root.width - width - Theme.s2
        y: root.wide ? root.pad + txt.height + Theme.s2 : root.pad + Math.max(0, (root.topH - height) / 2)
    }

    Rectangle {
        id: cmdBox
        visible: root.cmdOpen && root.command !== ""
        x: Theme.s2
        y: root.pad + root.topH + Theme.s1
        width: root.width - Theme.s2 * 2
        height: cmdText.implicitHeight + Theme.s2 * 2
        radius: Theme.rSm
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        TextEdit {
            id: cmdText
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.s2 }
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            text: "$ " + root.command
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall
            color: Theme.text2
            selectionColor: Theme.accent
            selectedTextColor: Theme.inkOnAccent
        }
    }

    Rectangle {
        visible: root.divider
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }
}
