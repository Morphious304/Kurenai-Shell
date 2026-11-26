import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking

// Reactive status indicators. No polling and no shell commands:
//   audio   -> Quickshell.Services.Pipewire
//   network -> Quickshell.Networking (NetworkManager backend)
//   battery -> Quickshell.Services.UPower
// Click any of them to toggle quick settings. Wheel over volume changes it.
// Middle-click volume / mic toggles mute.
Row {
    id: root
    spacing: Theme.s1

    // ---------------------------------------------------------------- audio
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var micNode: Pipewire.defaultAudioSource

    // Pipewire nodes only expose live values while tracked.
    PwObjectTracker { objects: [root.sink, root.micNode].filter(o => !!o) }

    readonly property bool hasSink: !!sink && !!sink.audio
    readonly property real volume: hasSink ? sink.audio.volume : 0
    readonly property bool sinkMuted: hasSink ? sink.audio.muted : true

    readonly property bool hasMic: !!micNode && !!micNode.audio
    readonly property bool micMuted: hasMic ? micNode.audio.muted : true

    function setVolume(v) {
        if (hasSink) sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleSinkMute() { if (hasSink) sink.audio.muted = !sink.audio.muted; }
    function toggleMicMute()  { if (hasMic)  micNode.audio.muted = !micNode.audio.muted; }

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
    BarItem {
        visible: root.hasMic
        icon: root.micMuted ? Theme.icons.micOff : Theme.icons.mic
        iconColor: root.micMuted ? Theme.muted : Theme.text
        onClicked: m => m.button === Qt.MiddleButton ? root.toggleMicMute() : UiState.toggleQuickSettings()
    }

    BarItem {
        icon: root.sinkMuted || root.volume <= 0 ? Theme.icons.volOff
            : root.volume < 0.5 ? Theme.icons.volDown : Theme.icons.volUp
        iconColor: root.sinkMuted ? Theme.muted : Theme.text
        label: root.sinkMuted ? "muted" : Math.round(root.volume * 100) + "%"
        labelColor: root.sinkMuted ? Theme.muted : Theme.text
        labelFamily: Theme.fontMono
        onClicked: m => m.button === Qt.MiddleButton ? root.toggleSinkMute() : UiState.toggleQuickSettings()
        onScrolled: d => root.setVolume(root.volume + (d > 0 ? 0.05 : -0.05))
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
