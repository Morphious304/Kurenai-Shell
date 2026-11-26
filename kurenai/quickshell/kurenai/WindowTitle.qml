import QtQuick
import Quickshell.Hyprland

// Active window title, elided on the right. Falls back to a muted "Desktop".
Item {
    id: root

    property real maxWidth: 480

    readonly property var focusedWindow: Hyprland.activeToplevel
    readonly property string titleText: (focusedWindow && focusedWindow.title) ? focusedWindow.title : ""

    implicitWidth: Math.min(Math.ceil(metrics.advanceWidth) + 2, maxWidth)
    implicitHeight: Theme.itemHeight

    TextMetrics {
        id: metrics
        font: label.font
        text: label.text
    }

    Text {
        id: label
        anchors.fill: parent
        text: root.titleText !== "" ? root.titleText : "Desktop"
        color: root.titleText !== "" ? Theme.text : Theme.muted
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBase
        font.weight: Font.Medium
    }
}
