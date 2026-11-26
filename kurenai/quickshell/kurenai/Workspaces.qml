import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shape carries the state, not colour alone:
//   active   = wide vermilion pill
//   occupied = solid bone dot
//   empty    = hollow ring
//   urgent   = amber dot
// Workspaces 1-5 always show; higher ones appear only while they exist.
Item {
    id: root

    required property var monitor      // HyprlandMonitor for the screen this bar is on

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    function find(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) return list[i];
        }
        return null;
    }

    readonly property var ids: {
        const out = [1, 2, 3, 4, 5];
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id > 5) out.push(list[i].id);
        }
        out.sort((a, b) => a - b);
        return out;
    }

    Row {
        id: row
        height: parent.height

        Repeater {
            // ScriptModel diffs the list, so delegates (and their animations) survive updates
            model: ScriptModel { values: root.ids }

            delegate: Item {
                id: cell
                required property int modelData

                readonly property var ws: root.find(modelData)
                readonly property bool isActive: !!ws && ws.active && ws.monitor === root.monitor
                readonly property bool isOccupied: !!ws && ws.toplevels.values.length > 0
                readonly property bool isUrgent: !!ws && ws.urgent && !isActive

                width: pill.width + Theme.s4
                height: row.height

                Rectangle {
                    id: pill
                    anchors.centerIn: parent
                    width: cell.isActive ? 20 : 8
                    height: 8
                    radius: 4
                    Behavior on width { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }

                    color: cell.isActive ? Theme.accent
                         : cell.isUrgent ? Theme.amber
                         : cell.isOccupied ? (area.containsMouse ? Theme.text : Theme.text2)
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    border.width: (cell.isActive || cell.isUrgent || cell.isOccupied) ? 0 : 1
                    border.color: area.containsMouse ? Theme.teal : Theme.muted
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(cell.modelData)
                }
            }
        }
    }

    // Scroll over the strip to step through open workspaces
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => Compositor.cycleWorkspace(e.angleDelta.y > 0 ? -1 : 1)
    }
}
