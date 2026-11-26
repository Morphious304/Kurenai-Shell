import QtQuick
import Quickshell
import Quickshell.Wayland

// Transient toasts, top-right of the focused monitor, just under the bar.
// The surface is only as big as the stack, and input is limited to the cards, so it never
// blocks clicks on windows underneath. Max simultaneous popups: Config.maxPopups.
PanelWindow {
    id: win

    screen: Compositor.focusedScreen
    visible: list.count > 0

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + Theme.popupMargin; right: Theme.popupMargin }
    implicitWidth: Theme.notifWidth
    implicitHeight: Math.max(1, list.contentHeight)

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "kurenai-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: list }

    ListView {
        id: list
        width: Theme.notifWidth
        height: contentHeight
        interactive: false
        spacing: Theme.s2

        // ScriptModel keeps delegates alive across updates, so add/remove transitions play
        model: ScriptModel { values: NotificationStore.popups }

        delegate: NotificationCard {
            required property var modelData
            notif: modelData
            popup: true
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durBase; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.durBase; easing.type: Easing.OutCubic }
            }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Theme.durBase; easing.type: Easing.OutCubic }
        }
    }
}
