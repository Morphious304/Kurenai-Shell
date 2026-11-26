import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// One bar per screen. Reserves its own height (exclusion mode Auto) so maximised
// windows never overlap it. Layer namespace "kurenai-bar" is what layer rules match.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusionMode: ExclusionMode.Auto
    color: Theme.bg
    WlrLayershell.namespace: "kurenai-bar"

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool wide: width >= 1100

    // bottom hairline
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }

    // ------------------------------------------------------------- left
    Row {
        id: left
        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        height: Theme.barHeight - 1
        spacing: Theme.s2

        Emblem {
            anchors.verticalCenter: parent.verticalCenter
            showWordmark: bar.wide
        }
        Divider { anchors.verticalCenter: parent.verticalCenter }
        Workspaces {
            monitor: bar.hyprMonitor
            height: parent.height
        }
    }

    // ----------------------------------------------------------- centre
    WindowTitle {
        anchors.centerIn: parent
        // never run into the side sections
        maxWidth: Math.max(120, bar.width - 2 * (Math.max(left.width, right.width) + Theme.s6))
    }

    // ------------------------------------------------------------ right
    Row {
        id: right
        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        spacing: Theme.s2

        Tray {
            id: tray
            visible: any
        }
        Divider { visible: tray.visible }

        Status {}

        Divider {}

        BarItem {
            icon: UiState.dnd ? Theme.icons.bellOff : Theme.icons.bell
            iconColor: UiState.notificationCount > 0 ? Theme.accentText : Theme.text2
            label: UiState.notificationCount > 0 ? String(UiState.notificationCount) : ""
            labelColor: Theme.accentText
            labelFamily: Theme.fontMono
            active: UiState.notificationsOpen
            onClicked: UiState.toggleNotifications()
        }

        Clock {}

        BarItem {
            icon: Theme.icons.sliders
            active: UiState.quickSettingsOpen
            onClicked: UiState.toggleQuickSettings()
        }
    }
}
