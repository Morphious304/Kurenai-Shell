import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared shell for every popover (notification centre, launcher, later quick settings).
// A full-screen, fully transparent layer surface that:
//   * appears on the focused monitor only,
//   * takes keyboard focus while open (Escape works, the launcher can type immediately),
//   * closes when you click anywhere outside the panel.
// Nothing is dimmed, so the wallpaper keeps its colours.
// Put a Surface as the child; it is placed according to `place`.
// (The child must have an explicit size; Surface does.)
PanelWindow {
    id: win

    property bool open: false
    property string place: "top-right"     // "top-right" | "top-center"
    property string layerName: "kurenai-panel"
    signal dismissed()

    default property alias content: holder.data

    screen: Compositor.focusedScreen
    visible: open || holder.opacity > 0.01

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.namespace: layerName
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // click outside = close
    MouseArea {
        anchors.fill: parent
        onClicked: win.dismissed()
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: win.dismissed()

        Item {
            id: holder
            // Children decide their own size; we only position and fade.
            readonly property real childW: childrenRect.width
            readonly property real childH: childrenRect.height
            width: childW
            height: childH

            x: win.place === "top-center" ? Math.round((parent.width - width) / 2)
                                          : parent.width - width - Theme.popupMargin
            y: win.place === "top-center" ? Math.round(parent.height * 0.16)
                                          : Theme.barHeight + Theme.popupMargin

            opacity: win.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }

            // slide in 8px from the edge it is anchored to
            transform: Translate {
                y: win.open ? 0 : -8
                Behavior on y { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
            }
        }
    }
}
