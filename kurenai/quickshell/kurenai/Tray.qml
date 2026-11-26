import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// Left click = activate, middle = secondary action, right = platform menu, wheel = scroll action.
Row {
    id: root
    spacing: Theme.s1

    readonly property bool any: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: cell
            required property var modelData

            readonly property var win: QsWindow.window

            width: Theme.itemHeight
            height: Theme.itemHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: m => {
                if (m.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (m.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu && win) {
                    const p = cell.mapToItem(null, 0, cell.height + Theme.s1);
                    modelData.display(win, Math.round(p.x), Math.round(p.y));
                }
            }
            onWheel: w => modelData.scroll(w.angleDelta.y, false)

            Rectangle {
                anchors.fill: parent
                radius: Theme.rSm
                color: cell.containsMouse ? Theme.raised : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: cell.modelData.icon
            }
        }
    }
}
