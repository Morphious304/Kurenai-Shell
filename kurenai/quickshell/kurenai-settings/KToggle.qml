import QtQuick

// On/off switch. State is shown by BOTH colour and knob position (not colour alone).
// Tab focuses it, Space/Enter flips it. It never flips itself: the owner updates `checked`
// in response to toggled(), so it always shows the real state of the thing it controls.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: enabled

    color: checked ? Theme.teal : Theme.surface
    border.width: 1
    border.color: checked ? Theme.teal : Theme.borderStrong
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.inkOnAccent : Theme.muted
        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    }

    Rectangle {      // focus ring
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.teal
        visible: root.activeFocus
    }

    function activate() { if (enabled) root.toggled(); }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
