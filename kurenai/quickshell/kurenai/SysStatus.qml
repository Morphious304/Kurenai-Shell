import QtQuick
import Quickshell.Services.UPower
import Quickshell.Networking

// Reactive status indicators. No polling and no shell commands:
//   audio   -> Quickshell.Services.Pipewire
//   network -> Quickshell.Networking (NetworkManager backend)
//   battery -> Quickshell.Services.UPower
// Audio state lives in Audio.qml (shared with the quick-settings panel).
// Click any indicator to toggle quick settings. Wheel over volume changes it.
// Middle-click volume / mic toggles mute.
Row {
    id: root
    spacing: Theme.s1

    // -------------------------------------------------------------- network
    readonly property var netDevices: Networking.devices ? Networking.devices.values : []
    readonly property string netKind: {
        let wifi = false;
        for (let i = 0; i < netDevices.length; i++) {
            const d = netDevices[i];
            if (!d.connected) continue;
            if (d.type === DeviceType.Wired) return "wired";
            if (d.type === DeviceType.Wifi) wifi = true;
        }
        return wifi ? "wifi" : "none";
    }

    // -------------------------------------------------------------- battery
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: !!bat && bat.isPresent
    readonly property real batPct: hasBat ? bat.percentage : 0        // 0..1
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property string batGlyph:
        batPct > 0.875 ? Theme.icons.bat4 :
        batPct > 0.625 ? Theme.icons.bat3 :
        batPct > 0.375 ? Theme.icons.bat2 :
        batPct > 0.125 ? Theme.icons.bat1 : Theme.icons.bat0
    readonly property color batColor:
        charging ? Theme.amber :
        batPct <= 0.15 ? Theme.accentText :
        batPct <= 0.30 ? Theme.amber : Theme.text2

    // ----------------------------------------------------------------- UI
    // visible reminders of things that keep running until you switch them off
    BarItem {
        visible: System.idleInhibit
        icon: Theme.icons.coffee
        iconColor: Theme.amber
        onClicked: UiState.toggleQuickSettings()
    }
    BarItem {
        visible: System.nightLight === "on"
        icon: Theme.icons.moon
        iconColor: Theme.amber
        onClicked: UiState.toggleQuickSettings()
    }

    BarItem {
        visible: Audio.hasSource
        icon: Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic
        iconColor: Audio.micMuted ? Theme.muted : Theme.text
        onClicked: m => m.button === Qt.MiddleButton ? Audio.toggleMicMute() : UiState.toggleQuickSettings()
    }

    BarItem {
        icon: Audio.muted || Audio.volume <= 0 ? Theme.icons.volOff
            : Audio.volume < 0.5 ? Theme.icons.volDown : Theme.icons.volUp
        iconColor: Audio.muted ? Theme.muted : Theme.text
        label: Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%"
        labelColor: Audio.muted ? Theme.muted : Theme.text
        labelFamily: Theme.fontMono
        onClicked: m => m.button === Qt.MiddleButton ? Audio.toggleMute() : UiState.toggleQuickSettings()
        onScrolled: d => Audio.setVolume(Audio.volume + (d > 0 ? 0.05 : -0.05))
    }

    BarItem {
        icon: root.netKind === "wired" ? Theme.icons.wired
            : root.netKind === "wifi" ? Theme.icons.wifi : Theme.icons.offline
        iconColor: root.netKind === "none" ? Theme.muted : Theme.text
        onClicked: UiState.toggleQuickSettings()
    }

    BarItem {
        visible: root.hasBat
        icon: (root.charging ? Theme.icons.bolt + " " : "") + root.batGlyph
        iconColor: root.batColor
        label: Math.round(root.batPct * 100) + "%"
        labelColor: root.batColor
        labelFamily: Theme.fontMono
        onClicked: UiState.toggleQuickSettings()
    }
}
