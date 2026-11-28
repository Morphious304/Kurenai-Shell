import QtQuick

// A titled row (icon, title, status line) with an optional on/off switch and an optional
// expand chevron; anything placed inside appears underneath when `expanded`.
Column {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool showToggle: false
    property bool toggleChecked: false
    property bool toggleEnabled: true
    property bool expandable: false
    property bool expanded: false

    signal toggled()
    signal expandToggled()

    default property alias content: extra.data
    spacing: Theme.s2

    Item {
        width: root.width
        height: 40

        // clicking the label area also expands (the chevron is the keyboard-reachable control)
        MouseArea {
            anchors.fill: parent
            enabled: root.expandable
            onClicked: root.expandToggled()
        }

        Text {
            id: glyph
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 22
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fsIcon + 2
            color: root.toggleChecked || !root.showToggle ? Theme.text : Theme.muted
        }

        Column {
            anchors {
                left: glyph.right; leftMargin: Theme.s2
                right: controls.left; rightMargin: Theme.s2
                verticalCenter: parent.verticalCenter
            }
            spacing: 1
            Text {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase + 1
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: root.subtitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                color: Theme.muted
            }
        }

        Row {
            id: controls
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.s2

            KToggle {
                visible: root.showToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.toggleChecked
                enabled: root.toggleEnabled
                onToggled: root.toggled()
            }
            Btn {
                visible: root.expandable
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                implicitHeight: 28
                height: 28
                flat: true
                center: true
                icon: root.expanded ? Theme.icons.chevUp : Theme.icons.chevDown
                iconSize: 11
                onClicked: root.expandToggled()
            }
        }
    }

    Column {
        id: extra
        width: root.width
        visible: root.expanded
        spacing: 2
    }
}
