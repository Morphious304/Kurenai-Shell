import QtQuick

// The 紅 hanko seal: the lock screen's status light.
//   pulse = slow breathing while a password/fingerprint is being checked
Rectangle {
    id: root

    property bool pulse: false
    property real size: 56

    width: size
    height: size
    radius: size * 0.2
    color: Theme.accent

    Text {
        anchors.centerIn: parent
        text: "\u7D05"
        font.family: Theme.fontDisplay
        font.pixelSize: root.size * 0.56
        font.weight: Font.Bold
        color: Theme.inkOnAccent
    }

    SequentialAnimation on opacity {
        running: root.pulse
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) root.opacity = 1
    }
}
