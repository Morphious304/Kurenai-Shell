import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// KURENAI quick settings. Opened from the bar (any status icon or the sliders button) or:
//   qs -c kurenai ipc call quicksettings toggle
// Every control acts on the real device/service; anything that is not available on this machine
// is hidden, or shown disabled WITH the reason. No passwords are handled here (see Wi-Fi).
PanelOverlay {
    id: root

    open: UiState.quickSettingsOpen
    place: "top-right"
    docked: Config.quickSettingsDocked && !Compositor.fullscreen
    layerName: "kurenai-quick-settings"
    onDismissed: UiState.quickSettingsOpen = false

    // which list is unfolded: "" | "sinks" | "sources" | "wifi" | "bluetooth"
    property string expandedSection: ""
    function toggleExpand(name) { expandedSection = expandedSection === name ? "" : name; }
    onOpenChanged: {
        if (open) System.refreshBrightness();
        else expandedSection = "";
    }

    readonly property real maxBodyH: (root.screen ? root.screen.height : 900) - Theme.barHeight - Theme.popupMargin * 2

    // ================================================================ battery
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: !!bat && bat.isPresent
    readonly property int batPct: hasBat ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: hasBat && bat.state === UPowerDeviceState.Charging
    readonly property bool discharging: hasBat && bat.state === UPowerDeviceState.Discharging

    function fmtDuration(sec) {
        const m = Math.round(sec / 60);
        if (m < 1) return "";
        const h = Math.floor(m / 60);
        return h > 0 ? h + " h " + (m % 60) + " min" : m + " min";
    }
    readonly property string batStatus: {
        if (!hasBat) return "";
        if (charging) {
            const t = fmtDuration(bat.timeToFull);
            return t !== "" ? "Charging, " + t + " to full" : "Charging";
        }
        if (discharging) {
            const t = fmtDuration(bat.timeToEmpty);
            return t !== "" ? "On battery, " + t + " left" : "On battery";
        }
        if (!UPower.onBattery) return batPct >= 99 ? "Fully charged" : "Plugged in, not charging";
        return "On battery";
    }
    readonly property string batDetail: {
        if (!hasBat) return "";
        const parts = [];
        if (bat.healthSupported && bat.healthPercentage > 0) parts.push("Health " + Math.round(bat.healthPercentage) + "%");
        if (Math.abs(bat.changeRate) >= 0.1) parts.push(Math.abs(bat.changeRate).toFixed(1) + " W");
        return parts.join("  \u00B7  ");
    }

    // ================================================================ network
    readonly property var netDevices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDev: {
        for (let i = 0; i < netDevices.length; i++) if (netDevices[i].type === DeviceType.Wifi) return netDevices[i];
        return null;
    }
    readonly property bool wiredUp: {
        for (let i = 0; i < netDevices.length; i++) {
            if (netDevices[i].type === DeviceType.Wired && netDevices[i].connected) return true;
        }
        return false;
    }

    // Scan only while the Wi-Fi list is actually open (saves power, avoids pointless radio use).
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.open && root.expandedSection === "wifi"
        when: !!root.wifiDev
    }

    // De-duplicated, stable order: connected, saved, then by signal bucket and name.
    readonly property var wifiList: {
        if (!wifiDev) return [];
        const src = wifiDev.networks.values;
        const byName = {};
        const out = [];
        for (let i = 0; i < src.length; i++) {
            const n = src[i];
            if (!n.name) continue;                                   // hidden SSIDs have no name to show
            const idx = byName[n.name];
            if (idx === undefined) { byName[n.name] = out.length; out.push(n); }
            else if (n.connected || (!out[idx].connected && n.signalStrength > out[idx].signalStrength)) out[idx] = n;
        }
        out.sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                        || (Math.round(b.signalStrength * 4) - Math.round(a.signalStrength * 4))
                        || a.name.localeCompare(b.name));
        return out;
    }
    readonly property var activeWifi: {
        for (let i = 0; i < wifiList.length; i++) if (wifiList[i].connected) return wifiList[i];
        return null;
    }
    readonly property string wifiSubtitle: {
        if (!wifiDev) return wiredUp ? "No Wi-Fi adapter  \u00B7  Ethernet connected" : "No Wi-Fi adapter";
        if (!Networking.wifiEnabled) return "Off";
        if (activeWifi) return activeWifi.name;
        for (let i = 0; i < wifiList.length; i++) if (wifiList[i].stateChanging) return "Connecting\u2026";
        return "Not connected";
    }

    // ================================================================ bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: {
        if (!btAdapter) return [];
        const src = btAdapter.devices.values;
        const out = [];
        for (let i = 0; i < src.length; i++) if (src[i].paired && src[i].name) out.push(src[i]);
        out.sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
        return out;
    }
    readonly property int btConnectedCount: {
        let n = 0;
        for (let i = 0; i < btDevices.length; i++) if (btDevices[i].connected) n++;
        return n;
    }
    readonly property string btSubtitle: {
        if (!btAdapter) return "No adapter, or the bluetooth service is not running";
        if (!btAdapter.enabled) return "Off";
        return btConnectedCount > 0 ? btConnectedCount + " connected" : "On";
    }

    // ================================================================ the panel
    PanelFrame {
        id: frame
        docked: root.docked
        bodyWidth: Theme.qsWidth
        bodyHeight: Math.min(flick.contentHeight + Theme.s3 * 2, root.maxBodyH)

        Flickable {
            id: flick
            anchors { fill: parent; margins: Theme.s3 }
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: flick.width
                spacing: Theme.s3

                // ---------------------------------------------------------------- title
                Item {
                    width: parent.width
                    height: 24
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Quick settings"
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 1
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        anchors { right: powerBtn.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                        text: "Esc to close"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: Theme.muted
                    }
                    Btn {
                        id: powerBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 28
                        height: 24
                        flat: true
                        center: true
                        icon: Theme.icons.power
                        iconSize: 12
                        onClicked: UiState.togglePowerMenu()      // opens the menu; nothing runs until you confirm there
                    }
                }

                // ---------------------------------------------------------------- battery + power profile
                Column {
                    visible: root.hasBat
                    width: parent.width
                    spacing: Theme.s2

                    Row {
                        width: parent.width
                        spacing: Theme.s3
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: root.charging ? Theme.icons.bolt : root.batPct > 62 ? Theme.icons.bat4
                                : root.batPct > 37 ? Theme.icons.bat2 : root.batPct > 12 ? Theme.icons.bat1 : Theme.icons.bat0
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fsIcon + 4
                            color: root.charging ? Theme.amber : root.batPct <= 15 ? Theme.accentText : Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batPct + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsBase + 5
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 22 - 60 - Theme.s3 * 2
                            spacing: 1
                            Text {
                                width: parent.width
                                text: root.batStatus
                                elide: Text.ElideRight
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsBase
                                color: Theme.text2
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: root.batDetail
                                elide: Text.ElideRight
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                color: Theme.muted
                            }
                        }
                    }

                    // Power profiles need power-profiles-daemon. Loader = we do not even talk to it if absent.
                    Loader {
                        width: parent.width
                        active: System.powerProfilesInstalled
                        visible: active
                        sourceComponent: Column {
                            spacing: Theme.s1
                            Row {
                                id: seg
                                width: parent.width
                                spacing: Theme.s1
                                readonly property real w3: (width - spacing * 2) / 3
                                Btn {
                                    width: seg.w3; height: 30; center: true
                                    text: "Saver"
                                    checked: PowerProfiles.profile === PowerProfile.PowerSaver
                                    onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                                }
                                Btn {
                                    width: seg.w3; height: 30; center: true
                                    text: "Balanced"
                                    checked: PowerProfiles.profile === PowerProfile.Balanced
                                    onClicked: PowerProfiles.profile = PowerProfile.Balanced
                                }
                                Btn {
                                    width: seg.w3; height: 30; center: true
                                    text: "Performance"
                                    enabled: PowerProfiles.hasPerformanceProfile
                                    checked: PowerProfiles.profile === PowerProfile.Performance
                                    onClicked: PowerProfiles.profile = PowerProfile.Performance
                                }
                            }
                            Text {
                                visible: !PowerProfiles.hasPerformanceProfile
                                width: parent.width
                                text: "Performance mode is not available on this machine."
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                color: Theme.muted
                            }
                        }
                    }
                }

                Rectangle { visible: root.hasBat; width: parent.width; height: 1; color: Theme.border }

                // ---------------------------------------------------------------- sound
                Column {
                    width: parent.width
                    spacing: Theme.s2

                    LevelRow {
                        width: parent.width
                        caption: "OUTPUT" + (Audio.hasSink ? "  \u00B7  " + Audio.label(Audio.sink) : "")
                        icon: Audio.muted || Audio.volume <= 0 ? Theme.icons.volOff
                            : Audio.volume < 0.5 ? Theme.icons.volDown : Theme.icons.volUp
                        muted: Audio.muted
                        value: Audio.volume
                        available: Audio.hasSink
                        unavailableText: "No audio output found. Is PipeWire running?"
                        expandable: Audio.sinks.length > 1
                        expanded: root.expandedSection === "sinks"
                        onMuteClicked: Audio.toggleMute()
                        onMoved: v => Audio.setVolume(v)
                        onExpandToggled: root.toggleExpand("sinks")
                    }
                    ListBox {
                        width: parent.width
                        visible: root.expandedSection === "sinks"
                        Repeater {
                            model: Audio.sinks
                            delegate: Btn {
                                required property var modelData
                                width: parent.width
                                icon: Theme.icons.headphones
                                text: Audio.label(modelData)
                                checked: Audio.isDefaultSink(modelData)
                                onClicked: Audio.setDefaultSink(modelData)
                            }
                        }
                    }

                    LevelRow {
                        width: parent.width
                        caption: "INPUT" + (Audio.hasSource ? "  \u00B7  " + Audio.label(Audio.source) : "")
                        icon: Audio.micMuted ? Theme.icons.micOff : Theme.icons.mic
                        muted: Audio.micMuted
                        value: Audio.micVolume
                        available: Audio.hasSource
                        unavailableText: "No microphone found."
                        expandable: Audio.sources.length > 1
                        expanded: root.expandedSection === "sources"
                        onMuteClicked: Audio.toggleMicMute()
                        onMoved: v => Audio.setMicVolume(v)
                        onExpandToggled: root.toggleExpand("sources")
                    }
                    ListBox {
                        width: parent.width
                        visible: root.expandedSection === "sources"
                        Repeater {
                            model: Audio.sources
                            delegate: Btn {
                                required property var modelData
                                width: parent.width
                                icon: Theme.icons.mic
                                text: Audio.label(modelData)
                                checked: Audio.isDefaultSource(modelData)
                                onClicked: Audio.setDefaultSource(modelData)
                            }
                        }
                    }

                    LevelRow {
                        visible: System.brightnessState !== "probing"
                        width: parent.width
                        caption: "BRIGHTNESS"
                        icon: Theme.icons.sun
                        showMute: false
                        value: System.brightness
                        available: System.brightnessState === "ok"
                        unavailableText: System.brightnessState === "missing"
                            ? "Brightness control needs brightnessctl (sudo pacman -S brightnessctl)."
                            : "No controllable backlight found on this display."
                        onMoved: v => System.setBrightness(v)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                // ---------------------------------------------------------------- Wi-Fi
                QsSection {
                    width: parent.width
                    icon: !root.wifiDev || !Networking.wifiEnabled ? Theme.icons.offline : Theme.icons.wifi
                    title: "Wi-Fi"
                    subtitle: root.wifiSubtitle
                    showToggle: !!root.wifiDev
                    toggleChecked: Networking.wifiEnabled
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    expandable: !!root.wifiDev && Networking.wifiEnabled
                    expanded: root.expandedSection === "wifi"
                    onExpandToggled: root.toggleExpand("wifi")

                    ListBox {
                        width: parent.width
                        Text {
                            visible: root.wifiList.length === 0
                            width: parent.width
                            text: "Scanning for networks\u2026"
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSmall
                            color: Theme.muted
                        }
                        Repeater {
                            model: root.wifiList
                            delegate: Btn {
                                required property var modelData
                                width: parent.width
                                icon: Theme.icons.wifi
                                text: modelData.name
                                checked: modelData.connected
                                trailing: Math.round(modelData.signalStrength * 100) + "%"
                                // password entry is never handled here: saved networks connect directly,
                                // new ones are set up in a trusted system tool (or nmtui/nmcli)
                                enabled: modelData.connected || modelData.known || System.networkTool !== ""
                                subtext: modelData.stateChanging ? "Working\u2026"
                                       : modelData.connected ? "Connected. Click to disconnect"
                                       : modelData.known ? ""
                                       : System.networkTool !== "" ? "Not saved. Opens " + System.networkTool
                                       : "Not saved. Add it with nmtui or nmcli"
                                onClicked: {
                                    if (modelData.connected) modelData.disconnect();
                                    else if (modelData.known) modelData.connect();
                                    else System.openTool(System.networkTool);
                                }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------------- Bluetooth
                QsSection {
                    width: parent.width
                    icon: Theme.icons.bluetooth
                    title: "Bluetooth"
                    subtitle: root.btSubtitle
                    showToggle: !!root.btAdapter
                    toggleChecked: !!root.btAdapter && root.btAdapter.enabled
                    onToggled: root.btAdapter.enabled = !root.btAdapter.enabled
                    expandable: !!root.btAdapter && root.btAdapter.enabled
                    expanded: root.expandedSection === "bluetooth"
                    onExpandToggled: root.toggleExpand("bluetooth")

                    ListBox {
                        width: parent.width
                        Text {
                            visible: root.btDevices.length === 0
                            width: parent.width
                            text: System.bluetoothTool !== "" ? "No paired devices yet." : "No paired devices. Pair one with bluetoothctl."
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSmall
                            color: Theme.muted
                        }
                        Repeater {
                            model: root.btDevices
                            delegate: Btn {
                                id: dev
                                required property var modelData
                                property bool busy: false
                                width: parent.width
                                icon: Theme.icons.bluetooth
                                text: modelData.name
                                checked: modelData.connected
                                trailing: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                                subtext: busy ? (modelData.connected ? "Disconnecting\u2026" : "Connecting\u2026")
                                       : modelData.connected ? "Connected. Click to disconnect" : ""
                                onClicked: {
                                    busy = true;
                                    busyTimer.restart();
                                    if (modelData.connected) modelData.disconnect();
                                    else modelData.connect();
                                }
                                Timer { id: busyTimer; interval: 10000; onTriggered: dev.busy = false }
                                Connections {
                                    target: dev.modelData
                                    function onConnectedChanged() { dev.busy = false; }
                                }
                            }
                        }
                    }
                    Btn {
                        visible: System.bluetoothTool !== ""
                        width: parent.width
                        height: 30
                        flat: true
                        icon: Theme.icons.cog
                        text: "Pair a new device\u2026"
                        onClicked: System.openTool(System.bluetoothTool)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }

                // ---------------------------------------------------------------- toggles
                Row {
                    id: tiles
                    width: parent.width
                    spacing: Theme.s2
                    readonly property bool nightShown: System.nightLight === "off" || System.nightLight === "on" || System.nightLight === "external"
                    readonly property real tileW: (width - spacing * (nightShown ? 2 : 1)) / (nightShown ? 3 : 2)

                    Btn {
                        width: tiles.tileW
                        height: 64
                        stacked: true
                        icon: NotificationStore.dnd ? Theme.icons.bellOff : Theme.icons.bell
                        text: "Do not disturb"
                        subtext: NotificationStore.dnd ? "On" : "Off"
                        checked: NotificationStore.dnd
                        onClicked: NotificationStore.toggleDnd()
                    }
                    Btn {
                        width: tiles.tileW
                        height: 64
                        stacked: true
                        icon: Theme.icons.coffee
                        text: "Keep awake"
                        subtext: System.idleInhibit ? "Screen stays on" : "Off"
                        checked: System.idleInhibit
                        onClicked: System.idleInhibit = !System.idleInhibit
                    }
                    Btn {
                        visible: tiles.nightShown
                        width: tiles.tileW
                        height: 64
                        stacked: true
                        icon: Theme.icons.moon
                        text: "Night light"
                        enabled: System.nightLight !== "external"
                        subtext: System.nightLight === "external" ? "Run by another program"
                               : System.nightLight === "on" ? Config.nightLightTemp + " K" : "Off"
                        checked: System.nightLight === "on"
                        onClicked: System.toggleNightLight()
                    }
                }

                // ---------------------------------------------------------------- shortcuts (installed tools only)
                Flow {
                    visible: System.audioTool !== "" || System.networkTool !== "" || System.bluetoothTool !== ""
                    width: parent.width
                    spacing: Theme.s2
                    Btn {
                        visible: System.audioTool !== ""
                        height: 30; width: 110; center: true
                        icon: Theme.icons.volUp; text: "Sound"
                        onClicked: System.openTool(System.audioTool)
                    }
                    Btn {
                        visible: System.networkTool !== ""
                        height: 30; width: 110; center: true
                        icon: Theme.icons.wifi; text: "Network"
                        onClicked: System.openTool(System.networkTool)
                    }
                    Btn {
                        visible: System.bluetoothTool !== ""
                        height: 30; width: 120; center: true
                        icon: Theme.icons.bluetooth; text: "Bluetooth"
                        onClicked: System.openTool(System.bluetoothTool)
                    }
                }
            }
        }
    }
}
