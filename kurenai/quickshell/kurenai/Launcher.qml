import QtQuick
import Quickshell
import Quickshell.Widgets

// KURENAI launcher. Real desktop entries from DesktopEntries (see Apps.qml).
//   type       filter          Up/Down, Ctrl+N/P, Ctrl+J/K   move
//   Enter      launch          Ctrl+F                        favourite / unfavourite
//   Esc        close           click outside                 close
// Opened from Hyprland with: qs -c kurenai ipc call launcher toggle
PanelOverlay {
    id: root

    open: UiState.launcherOpen
    place: "top-center"
    layerName: "kurenai-launcher"
    onDismissed: UiState.launcherOpen = false

    // fresh state every time it opens
    onOpenChanged: {
        if (open) {
            input.text = "";
            results.currentIndex = 0;
            // the layer surface is mapped a moment after `open` flips; focus once it is
            Qt.callLater(() => input.forceActiveFocus());
        }
    }

    readonly property var found: Apps.search(input.text)

    function launchCurrent() {
        const e = found[results.currentIndex];
        if (!e) return;
        Apps.launch(e);
        UiState.launcherOpen = false;
    }

    Surface {
        id: panel
        width: Theme.launcherWidth
        height: (Theme.s3 + 2) + bar.height + Theme.s2 + listArea.height + footer.height

        // ---- search field -------------------------------------------------------------------
        Rectangle {
            id: bar
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.s3; topMargin: Theme.s3 + 2 }
            height: 40
            radius: Theme.rMd
            color: Theme.surface
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                text: Theme.icons.search
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fsIcon
                color: input.activeFocus ? Theme.accentText : Theme.muted
            }

            TextInput {
                id: input
                anchors { left: glyph.right; right: seal.left; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase + 2
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.inkOnAccent
                cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                clip: true
                focus: true

                onTextChanged: results.currentIndex = 0

                Keys.onPressed: e => {
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_N || e.key === Qt.Key_J))) {
                        results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_P || e.key === Qt.Key_K))) {
                        results.currentIndex = Math.max(0, results.currentIndex - 1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.launchCurrent();
                        e.accepted = true;
                    } else if (ctrl && e.key === Qt.Key_F) {
                        const en = root.found[results.currentIndex];
                        if (en) Apps.toggleFavorite(en.id);
                        e.accepted = true;
                    }
                }

                Text {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search applications"
                    font: input.font
                    color: Theme.muted
                }
            }

            // small hanko seal: the one ornamental accent
            Rectangle {
                id: seal
                anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                width: 24
                height: 24
                radius: Theme.rSm
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: "\u7D05"
                    font.family: Theme.fontDisplay
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.inkOnAccent
                }
            }
        }

        // ---- results -----------------------------------------------------------------------------
        Item {
            id: listArea
            anchors { top: bar.bottom; left: parent.left; right: parent.right; topMargin: Theme.s2; leftMargin: Theme.s2; rightMargin: Theme.s2 }
            height: Math.max(results.count > 0 ? Math.min(results.count, Config.launcherVisibleRows) * Theme.launcherRowHeight : 96, 96)

            ListView {
                id: results
                anchors.fill: parent
                clip: true
                visible: count > 0
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 90
                currentIndex: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                model: ScriptModel { values: root.found }

                highlight: Rectangle {
                    radius: Theme.rMd
                    color: Theme.raised
                    Rectangle {      // vermilion selection rule
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
                        width: 3
                        radius: 1.5
                        color: Theme.accent
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: results.width
                    height: Theme.launcherRowHeight

                    readonly property bool fav: Apps.isFavorite(modelData.id)

                    Row {
                        anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s3 }
                        spacing: Theme.s3

                        Item {
                            width: 28
                            height: parent.height
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 26
                                source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon) : ""
                                visible: row.modelData.icon !== ""
                            }
                            Rectangle {      // missing icon: rose initial tile
                                visible: !row.modelData.icon
                                anchors.centerIn: parent
                                width: 26; height: 26
                                radius: Theme.rSm
                                color: Theme.raised
                                Text {
                                    anchors.centerIn: parent
                                    text: row.modelData.name.charAt(0).toUpperCase()
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsBase
                                    font.weight: Font.Bold
                                    color: Theme.rose
                                }
                            }
                        }

                        Column {
                            width: parent.width - 28 - Theme.s3 * 2 - 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: row.modelData.name
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsBase + 1
                                font.weight: Font.Medium
                                color: Theme.text
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: row.modelData.genericName || row.modelData.comment || ""
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                color: Theme.teal
                            }
                        }

                        Text {      // favourite marker
                            width: 18
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            visible: row.fav
                            text: Theme.icons.star
                            font.family: Theme.fontIcon
                            font.pixelSize: 12
                            color: Theme.amber
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: results.currentIndex = row.index
                        onClicked: { results.currentIndex = row.index; root.launchCurrent(); }
                    }
                }
            }

            // empty state
            Column {
                visible: results.count === 0
                anchors.centerIn: parent
                spacing: Theme.s1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No applications match \u201C" + input.text.trim() + "\u201D"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, listArea.width - Theme.s6)
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                    color: Theme.text2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Apps.all.length === 0 ? "No desktop entries found on this system." : "Check the spelling, or try the Rofi fallback."
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
            }
        }

        // ---- key hints ---------------------------------------------------------------------------------
        Item {
            id: footer
            anchors { top: listArea.bottom; left: parent.left; right: parent.right }
            height: 30
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3 } height: 1; color: Theme.border }
            Text {
                anchors { left: parent.left; leftMargin: Theme.s4; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                text: "\u21B5 launch   \u2191\u2193 move   Ctrl+F favourite   Esc close"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSmall - 1
                color: Theme.muted
            }
        }
    }
}
