import QtQuick

// One typed character = one plum-blossom (ume): five vermilion lobes and a bone-coloured centre.
// It pops in when it is created.
Item {
    id: root

    property real size: 36

    width: size
    height: size
    scale: 0.2
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    Component.onCompleted: scale = 1

    Repeater {
        model: 5
        delegate: Rectangle {
            required property int index
            readonly property real a: (index * 72 - 90) * Math.PI / 180
            width: root.size * 0.44
            height: width
            radius: width / 2
            color: Theme.accent
            x: root.size / 2 - width / 2 + Math.cos(a) * root.size * 0.26
            y: root.size / 2 - height / 2 + Math.sin(a) * root.size * 0.26
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.2
        height: width
        radius: width / 2
        color: Theme.text
    }
}
