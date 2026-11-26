import QtQuick
import Quickshell
import Quickshell.Services.UPower

// System monitor: CPU, memory, CPU temperature (if there is a sensor), battery, storage.
// Opened with SUPER+I, the chart button in quick settings, or: qs -c kurenai ipc call sysmon toggle
// It reads data ONLY while open (see SysMon.qml); nothing runs in the background.
PanelOverlay {
    id: root

    open: UiState.sysmonOpen
    place: "top-right"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-sysmon"
    onDismissed: UiState.sysmonOpen = false

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: !!bat && bat.isPresent
    readonly property string batDetail: {
        if (!hasBat) return "";
        const parts = [];
        parts.push(bat.state === UPowerDeviceState.Charging ? "Charging" : bat.state === UPowerDeviceState.Discharging ? "On battery"
                   : UPower.onBattery ? "On battery" : "Plugged in");
        if (Math.abs(bat.changeRate) >= 0.1) parts.push(Math.abs(bat.changeRate).toFixed(1) + " W");
        if (bat.healthSupported && bat.healthPercentage > 0) parts.push("health " + Math.round(bat.healthPercentage) + "%");
        return parts.join("  \u00B7  ");
    }

    PanelFrame {
        docked: root.docked
        bodyWidth: 340
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s3

            Item {
                width: parent.width
                height: 24
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "System"
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 1
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "updates while open"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall - 1
                    color: Theme.muted
                }
            }

            MeterRow {
                width: parent.width
                label: "CPU"
                value: SysMon.cpu < 0 ? "\u2026" : Math.round(SysMon.cpu) + "%"
                fraction: SysMon.cpu < 0 ? 0 : SysMon.cpu / 100
                detail: "load  " + SysMon.load.join("  ")
            }

            MeterRow {
                width: parent.width
                label: "MEMORY"
                value: SysMon.memTotal > 0 ? SysMon.gibKb(SysMon.memUsed) + " / " + SysMon.gibKb(SysMon.memTotal) : "\u2026"
                fraction: SysMon.memTotal > 0 ? SysMon.memUsed / SysMon.memTotal : 0
                detail: SysMon.swapTotal > 0 ? "swap  " + SysMon.gibKb(SysMon.swapUsed) + " / " + SysMon.gibKb(SysMon.swapTotal) : "no swap"
            }

            MeterRow {
                visible: SysMon.temp >= 0
                width: parent.width
                label: "CPU TEMPERATURE"
                value: SysMon.temp + " \u00B0C"
                fraction: Math.min(1, SysMon.temp / 100)
            }

            MeterRow {
                visible: root.hasBat
                width: parent.width
                label: "BATTERY"
                lowIsBad: true
                value: root.hasBat ? Math.round(root.bat.percentage * 100) + "%" : ""
                fraction: root.hasBat ? root.bat.percentage : 0
                detail: root.batDetail
            }

            Rectangle { visible: SysMon.disks.length > 0; width: parent.width; height: 1; color: Theme.border }

            Column {
                visible: SysMon.disks.length > 0
                width: parent.width
                spacing: Theme.s3
                Repeater {
                    model: SysMon.disks
                    delegate: MeterRow {
                        required property var modelData
                        width: parent.width
                        label: "STORAGE  " + modelData.mount
                        value: SysMon.gib(modelData.used) + " / " + SysMon.gib(modelData.size)
                        fraction: modelData.size > 0 ? modelData.used / modelData.size : 0
                        detail: modelData.size > 0 ? Math.round(modelData.used / modelData.size * 100) + "% used" : ""
                    }
                }
            }

            Text {
                visible: !SysMon.ok
                width: parent.width
                wrapMode: Text.Wrap
                text: "Reading system data\u2026 (needs ~/.local/bin/kurenai-sysmon; run install.sh if this stays)"
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                color: Theme.muted
            }
        }
    }
}
