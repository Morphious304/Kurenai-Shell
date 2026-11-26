import QtQuick
import Quickshell.Hyprland

// Active window title, elided on the right. Falls back to a muted "Desktop".
Item {
    id: root

    property real maxWidth: 480

    readonly property var activeWin: Hyprland.activeToplevel
    readonly property string shownTitle: (activeWin && activeWin.title) ? activeWin.title : ""

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
        text: root.shownTitle !== "" ? root.shownTitle : "Desktop"
        color: root.shownTitle !== "" ? Theme.text : Theme.muted
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBase
        font.weight: Font.Medium
    }
}
