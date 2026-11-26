import QtQuick
import Quickshell

// History + Do Not Disturb. Opened from the bar bell, or: qs -c kurenai ipc call notifications toggle
PanelOverlay {
    id: root

    open: UiState.notificationsOpen
    place: "top-right"
    layerName: "kurenai-notification-center"
    onDismissed: UiState.notificationsOpen = false

    // Height budget comes from the screen, not from the panel, so sizing never loops.
    readonly property real maxPanelH: (root.screen ? root.screen.height : 900) - Theme.barHeight - Theme.popupMargin * 2
    readonly property real chromeH: Theme.s3 * 2 /*padding*/ + 28 /*header*/ + 1 /*rule*/ + Theme.s3 * 2 /*spacing*/

    Surface {
        id: panel
        width: Theme.centerWidth
        height: Math.min(content.implicitHeight + Theme.s3 * 2, root.maxPanelH)

        Column {
            id: content
            anchors { fill: parent; margins: Theme.s3 }
            spacing: Theme.s3

            // ---- header: title on the left, DND + clear on the right ------------------------
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 1
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NotificationStore.count > 0
                        text: String(NotificationStore.count)
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall
                        color: Theme.accentText
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2

                    // Do Not Disturb toggle: the same flag quick settings will use
                    Rectangle {
                        width: dndRow.implicitWidth + Theme.s3 * 2
                        height: 26
                        radius: Theme.rSm
                        color: NotificationStore.dnd ? Theme.accent : (dndArea.containsMouse ? Theme.raised : "transparent")
                        border.width: NotificationStore.dnd ? 0 : 1
                        border.color: Theme.borderStrong
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Row {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: Theme.s1 + 2
                            Text {
                                text: NotificationStore.dnd ? Theme.icons.bellOff : Theme.icons.bell
                                font.family: Theme.fontIcon
                                font.pixelSize: 12
                                color: NotificationStore.dnd ? Theme.inkOnAccent : Theme.text2
                            }
                            Text {
                                text: "Do not disturb"
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall + 1
                                font.weight: Font.Medium
                                color: NotificationStore.dnd ? Theme.inkOnAccent : Theme.text2
                            }
                        }
                        MouseArea {
                            id: dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationStore.toggleDnd()
                        }
                    }

                    // Clear all (disabled when empty)
                    Rectangle {
                        width: 26
                        height: 26
                        radius: Theme.rSm
                        opacity: NotificationStore.count > 0 ? 1 : 0.4
                        color: clearArea.containsMouse && NotificationStore.count > 0 ? Theme.raised : "transparent"
                        border.width: 1
                        border.color: Theme.borderStrong
                        Text {
                            anchors.centerIn: parent
                            text: Theme.icons.trash
                            font.family: Theme.fontIcon
                            font.pixelSize: 12
                            color: Theme.text2
                        }
                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: NotificationStore.count > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationStore.clearAll()
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---- empty state ----------------------------------------------------------
            Item {
                visible: NotificationStore.count === 0
                width: parent.width
                height: 150
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.s2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "\u9759"                      // "stillness": decorative only
                        font.family: Theme.fontDisplay
                        font.pixelSize: 40
                        color: Theme.raised
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: NotificationStore.dnd ? "All quiet. Do not disturb is on." : "All quiet. Nothing new."
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase
                        color: Theme.muted
                    }
                }
            }

            // ---- history (newest first) -----------------------------------------------------
            ListView {
                id: hist
                visible: NotificationStore.count > 0
                width: parent.width
                // fill whatever height the panel has left, never more than the content
                height: Math.min(contentHeight, root.maxPanelH - root.chromeH)
                clip: true
                spacing: Theme.s2
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: NotificationStore.history }

                delegate: NotificationCard {
                    required property var modelData
                    width: hist.width
                    notif: modelData
                    popup: false
                }

                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.durBase; easing.type: Easing.OutCubic } }
            }
        }
    }
}
