import QtQuick
import Quickshell
import Quickshell.Wayland

// Transient toasts, top-right of the focused monitor, just under the bar.
// The surface is only as big as the stack, and input is limited to the cards, so it never
// blocks clicks on windows underneath. Max simultaneous popups: Config.maxPopups.
PanelWindow {
    id: win

    screen: Compositor.focusedScreen
    // Decided from the store, NOT from the stack inside this window: an invisible window never builds its contents,
    // so a "visible when the list has items" rule can never become true (found by running it in a real Quickshell).
    visible: NotificationStore.popups.length > 0

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + Theme.popupMargin; right: Theme.popupMargin }
    implicitWidth: Theme.notifWidth
    implicitHeight: Math.max(1, stack.implicitHeight)

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "kurenai-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: stack }

    // A Column re-stacks when a card's height settles after its text wraps; a ListView placed new cards using the
    // height they had at creation, so they overlapped.
    Column {
        id: stack
        width: Theme.notifWidth
        spacing: Theme.s2

        // ScriptModel keeps delegates alive across updates
        Repeater {
            model: ScriptModel { values: NotificationStore.popups }

            NotificationCard {
                required property var modelData
                notif: modelData
                popup: true
            }
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durBase; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.durBase; easing.type: Easing.OutCubic }
            }
        }
        move: Transition {
            NumberAnimation { properties: "y"; duration: Theme.durBase; easing.type: Easing.OutCubic }
        }
    }
}
