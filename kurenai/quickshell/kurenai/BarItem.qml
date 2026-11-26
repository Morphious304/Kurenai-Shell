import QtQuick

// Generic bar button: optional glyph + optional label. Hover = raised surface,
// active (e.g. its panel is open) = vermilion fill with dark text.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.text
    property color labelColor: Theme.text
    property string labelFamily: Theme.fontUi
    property bool active: false

    readonly property bool hovered: area.containsMouse

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitHeight: Theme.itemHeight
    implicitWidth: row.implicitWidth + Theme.s2 * 2
    radius: Theme.rSm
    color: active ? Theme.accent : (hovered ? Theme.raised : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.s1

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fsIcon
            color: root.active ? Theme.inkOnAccent : root.iconColor
        }

        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: root.labelFamily
            font.pixelSize: Theme.fsBase
            font.weight: Font.Medium
            color: root.active ? Theme.inkOnAccent : root.labelColor
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }
}
