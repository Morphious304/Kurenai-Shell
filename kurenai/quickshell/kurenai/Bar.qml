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
    // The window itself is always transparent (a surface gets its alpha channel when it is created, which is before the
    // settings file has been read); the colour is drawn by the Rectangle below, so glassOpacity can change at any time.
    color: "transparent"
    WlrLayershell.namespace: "kurenai-bar"

    // "Keep awake" (quick settings). Attached to the bar because an inhibitor only counts while its
    // window is visible; one per bar is harmless on multi-monitor setups.
    IdleInhibitor {
        window: bar
        enabled: System.idleInhibit
    }

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property bool wide: width >= 1100

    // bar background (solid by default; translucent when Settings > glassOpacity is below 100)
    Rectangle {
        anchors.fill: parent
        color: Glass.barBg
    }

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

        // current track; only exists while an MPRIS player is running
        BarItem {
            id: mediaItem
            visible: Media.has
            icon: Media.playing ? Theme.icons.music : Theme.icons.pause
            iconColor: Media.playing ? Theme.rose : Theme.muted
            label: bar.wide ? Media.barText() : ""
            labelColor: Media.playing ? Theme.text : Theme.muted
            active: UiState.mediaOpen
            onClicked: m => m.button === Qt.MiddleButton ? Media.togglePlaying() : UiState.toggleMedia()
        }
        Divider { visible: mediaItem.visible }

        Tray {
            id: tray
            visible: any
        }
        Divider { visible: tray.visible }

        SysStatus {}

        Divider {}

        BarItem {
            icon: NotificationStore.dnd ? Theme.icons.bellOff : Theme.icons.bell
            iconColor: NotificationStore.hasCritical ? Theme.accent
                     : NotificationStore.count > 0 ? Theme.accentText : Theme.text2
            label: NotificationStore.count > 0 ? String(NotificationStore.count) : ""
            labelColor: Theme.accentText
            labelFamily: Theme.fontMono
            active: UiState.notificationsOpen
            onClicked: m => m.button === Qt.MiddleButton ? NotificationStore.toggleDnd() : UiState.toggleNotifications()
        }

        Clock {}

        BarItem {
            icon: Theme.icons.sliders
            active: UiState.quickSettingsOpen
            onClicked: UiState.toggleQuickSettings()
        }
    }
}
