import QtQuick
import Quickshell

// Session menu: Lock, Suspend, Log out, Reboot, Shut down.
//   * only actions that really exist are listed (Lock appears only if a lock tool is installed),
//   * Log out / Reboot / Shut down ask for an explicit second click (auto-cancels after 10 s),
//   * nothing ever runs because the panel opened or has focus: no entry is pre-selected,
//   * plain commands, never sudo.
// Opened with: qs -c kurenai ipc call powermenu toggle   (or the power button in quick settings)
PanelOverlay {
    id: root

    open: UiState.powerMenuOpen
    place: "top-right"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-power"
    onDismissed: UiState.powerMenuOpen = false

    // id of the action waiting for confirmation, or ""
    property string pending: ""
    readonly property var pendingAction: {
        for (let i = 0; i < Power.actions.length; i++) if (Power.actions[i].id === pending) return Power.actions[i];
        return null;
    }
    onOpenChanged: { pending = ""; if (open) System.probeLockDaemon(); }

    Timer {
        interval: 10000
        running: root.pending !== ""
        onTriggered: root.pending = ""
    }

    function choose(a) {
        if (a.confirm) { pending = a.id; return; }
        Power.run(a.id);
        UiState.powerMenuOpen = false;
    }

    PanelFrame {
        docked: root.docked
        bodyWidth: 268
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s2

            Text {
                text: root.pending === "" ? "Session" : "Are you sure?"
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase + 1
                font.weight: Font.DemiBold
                color: Theme.text
            }

            // ---------------------------------------------------------------- the menu
            Column {
                visible: root.pending === ""
                width: parent.width
                spacing: 2
                Repeater {
                    model: Power.actions
                    delegate: Btn {
                        required property var modelData
                        width: parent.width
                        height: 44
                        icon: modelData.icon
                        text: modelData.label
                        subtext: modelData.detail
                        onClicked: root.choose(modelData)
                    }
                }
                Text {
                    visible: !Power.canLock
                    width: parent.width
                    topPadding: Theme.s1
                    wrapMode: Text.Wrap
                    text: "No lock screen found (hyprlock, swaylock, gtklock or waylock). Install one to get a Lock entry."
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
            }

            // ---------------------------------------------------------------- confirmation
            Column {
                visible: root.pending !== ""
                width: parent.width
                spacing: Theme.s3

                Row {
                    spacing: Theme.s3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingAction ? root.pendingAction.icon : ""
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fsIcon + 8
                        color: Theme.accentText
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: root.pendingAction ? root.pendingAction.label + " now?" : ""
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase + 2
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            text: root.pendingAction ? root.pendingAction.detail + ". Unsaved work may be lost." : ""
                            width: col.width - 48
                            wrapMode: Text.Wrap
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSmall
                            color: Theme.muted
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.s2
                    // Cancel comes first in the Tab order and nothing is pre-focused: deliberate action only.
                    Btn {
                        width: (parent.width - Theme.s2) / 2
                        height: 36
                        center: true
                        text: "Cancel"
                        onClicked: root.pending = ""
                    }
                    Rectangle {
                        width: (parent.width - Theme.s2) / 2
                        height: 36
                        radius: Theme.rMd
                        color: confirmArea.containsMouse || activeFocus ? Qt.lighter(Theme.accentDeep, 1.2) : Theme.accentDeep
                        activeFocusOnTab: true
                        Text {
                            anchors.centerIn: parent
                            text: root.pendingAction ? root.pendingAction.label : ""
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Rectangle {          // focus ring
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.teal
                            visible: parent.activeFocus
                        }
                        function fire() {
                            const id = root.pending;
                            root.pending = "";
                            UiState.powerMenuOpen = false;
                            if (id !== "") Power.run(id);
                        }
                        Keys.onReturnPressed: fire()
                        Keys.onEnterPressed: fire()
                        Keys.onSpacePressed: fire()
                        MouseArea {
                            id: confirmArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.fire()
                        }
                    }
                }
            }
        }
    }
}
