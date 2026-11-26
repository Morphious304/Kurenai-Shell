import QtQuick
import Quickshell
import "BindParser.js" as BP

// Keyboard shortcuts, read live from your Hyprland Lua config (see Keybinds.qml for how).
//   type          filter (every word must match: "super shift", "volume", "kurenai", a file name)
//   Up/Down       scroll          PageUp/PageDown   scroll a page      Home/End  top / bottom
//   Esc           close           click outside     close
// Opened with: qs -c kurenai ipc call shortcuts toggle   (default bind in kurenai-binds.lua: SUPER + SLASH)
PanelOverlay {
    id: root

    open: UiState.shortcutsOpen
    place: "top-center"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-shortcuts"
    onDismissed: UiState.shortcutsOpen = false

    onOpenChanged: {
        if (open) {
            input.text = "";
            infoOpen = false;
            Keybinds.refresh();                       // always show what is on disk right now
            Qt.callLater(() => { input.forceActiveFocus(); list.contentY = 0; });
        }
    }

    property bool infoOpen: false

    readonly property int rowH: 38
    readonly property int headH: 32
    readonly property int bodyW: 720

    // search first, then collapse runs like Super+1..0, then group by category
    readonly property var shown: BP.filterEntries(Keybinds.entries, input.text)
    readonly property var rows: BP.toRows(BP.collapse(shown))

    function scrollBy(dy) {
        list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + dy));
    }

    PanelFrame {
        id: frame
        docked: root.docked
        bodyWidth: root.bodyW
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s2

            // ---------------------------------------------------------------- header
            Item {
                width: parent.width
                height: 30

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Keyboard shortcuts"
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 4
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {                            // decorative: "key" (a Japanese font is optional)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u9375"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fsBase
                        color: Theme.accentText
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shown.length === Keybinds.entries.length
                              ? Keybinds.entries.length + " shortcuts"
                              : root.shown.length + " of " + Keybinds.entries.length
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                    }
                    Btn {
                        width: 28; height: 28
                        flat: true; center: true
                        icon: Theme.icons.reboot
                        iconSize: 12
                        onClicked: Keybinds.refresh()
                    }
                }
            }

            // ---------------------------------------------------------------- search
            Rectangle {
                width: parent.width
                height: 38
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
                    anchors { left: glyph.right; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 1
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.inkOnAccent
                    cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                    clip: true
                    focus: true

                    onTextChanged: list.contentY = 0

                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Down) { root.scrollBy(root.rowH * 2); e.accepted = true; }
                        else if (e.key === Qt.Key_Up) { root.scrollBy(-root.rowH * 2); e.accepted = true; }
                        else if (e.key === Qt.Key_PageDown) { root.scrollBy(list.height - root.rowH); e.accepted = true; }
                        else if (e.key === Qt.Key_PageUp) { root.scrollBy(-(list.height - root.rowH)); e.accepted = true; }
                        else if (e.key === Qt.Key_Home && !input.text) { list.contentY = 0; e.accepted = true; }
                        else if (e.key === Qt.Key_End && !input.text) { root.scrollBy(1e6); e.accepted = true; }
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search: a key, an action, a program, a file"
                        font: input.font
                        color: Theme.muted
                    }
                }
            }

            // ---------------------------------------------------------------- list
            Item {
                id: listArea
                width: parent.width
                height: Math.max(120, Math.min(list.contentHeight, Config.shortcutsVisibleRows * root.rowH))

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    visible: count > 0
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.rows

                    delegate: Item {
                        id: row
                        required property var modelData
                        readonly property bool isHead: modelData.type === "header"
                        readonly property var e: modelData.e

                        width: list.width
                        height: isHead ? root.headH : root.rowH

                        // ---- category header
                        Item {
                            visible: row.isHead
                            anchors.fill: parent
                            Text {
                                id: headText
                                anchors { left: parent.left; leftMargin: Theme.s2; bottom: parent.bottom; bottomMargin: 5 }
                                text: row.isHead ? row.modelData.title.toUpperCase() : ""
                                textFormat: Text.PlainText
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsSmall
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: Theme.teal
                            }
                            Text {
                                anchors { left: headText.right; leftMargin: Theme.s2; baseline: headText.baseline }
                                text: row.isHead ? row.modelData.count : ""
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsSmall
                                color: Theme.muted
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Theme.s2; rightMargin: Theme.s2 }
                                height: 1
                                color: Theme.border
                            }
                        }

                        // ---- one shortcut
                        Item {
                            visible: !row.isHead
                            anchors.fill: parent

                            Rectangle {                              // hover wash
                                anchors { fill: parent; leftMargin: 2; rightMargin: 2 }
                                radius: Theme.rSm
                                color: Theme.raised
                                opacity: hover.containsMouse ? 0.7 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                            }
                            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                            // keys
                            Row {
                                id: caps
                                anchors { left: parent.left; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                                width: 236
                                spacing: 4
                                clip: true
                                Repeater {
                                    model: row.e ? row.e.caps : []
                                    delegate: Rectangle {
                                        required property string modelData
                                        required property int index
                                        readonly property bool isSuper: modelData === "Super"
                                        height: 22
                                        width: capText.implicitWidth + 14
                                        radius: 5
                                        color: Theme.surface
                                        border.width: 1
                                        border.color: isSuper ? Theme.accentDeep : Theme.borderStrong
                                        Text {
                                            id: capText
                                            anchors.centerIn: parent
                                            text: modelData
                                            textFormat: Text.PlainText
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fsSmall
                                            font.weight: Font.Medium
                                            color: isSuper ? Theme.accentText : Theme.text
                                        }
                                    }
                                }
                            }

                            // what it does
                            Column {
                                anchors {
                                    left: caps.right; leftMargin: Theme.s3
                                    right: tags.left; rightMargin: Theme.s2
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 0
                                Text {
                                    width: parent.width
                                    text: row.e ? row.e.label : ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsBase
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: row.e ? row.e.detail : ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fsSmall - 1
                                    color: Theme.muted
                                }
                            }

                            // status + source
                            Row {
                                id: tags
                                anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                                spacing: Theme.s2
                                layoutDirection: Qt.RightToLeft

                                Text {                                  // file:line (rightmost)
                                    visible: !!row.e && row.e.file !== ""
                                    text: row.e && row.e.file !== "" ? BP.baseName(row.e.file) + ":" + row.e.line : ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideLeft
                                    width: Math.min(implicitWidth, 150)
                                    horizontalAlignment: Text.AlignRight
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fsSmall - 1
                                    color: Theme.muted
                                }
                                Text {
                                    visible: !!row.e && row.e.source === "runtime"
                                    text: "Hyprland only"
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSmall - 1
                                    font.weight: Font.Medium
                                    color: Theme.teal
                                }
                                Text {
                                    visible: !!row.e && row.e.source === "config" && row.e.live === false
                                    text: "not active"
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSmall - 1
                                    font.weight: Font.Medium
                                    color: Theme.amber
                                }
                                Text {
                                    visible: !!row.e && row.e.dup === true
                                    text: "duplicate"
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSmall - 1
                                    font.weight: Font.Medium
                                    color: Theme.rose
                                }
                                Text {
                                    visible: !!row.e && !!row.e.flags && row.e.flags.indexOf("locked") >= 0
                                    text: "works when locked"
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSmall - 1
                                    color: Theme.muted
                                }
                            }
                        }
                    }
                }

                // ---- empty / problem states
                Column {
                    visible: list.count === 0
                    anchors.centerIn: parent
                    width: parent.width - Theme.s6 * 2
                    spacing: Theme.s1
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase
                        color: Theme.text2
                        text: Keybinds.state === "nomain" ? "Could not find your Hyprland config"
                            : Keybinds.state === "error" ? "The shortcuts reader hit a problem"
                            : Keybinds.state === "loading" ? "Reading your config…"
                            : input.text.trim() !== "" ? "No shortcuts match “" + input.text.trim() + "”"
                            : "No keybinds found in your config"
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                        text: Keybinds.state === "nomain" ? Keybinds.mainFile + "\nIf your config lives elsewhere, set hyprMainFile in Config.qml."
                            : Keybinds.state === "error" ? Keybinds.errorText
                            : ""
                    }
                }
            }

            // ---------------------------------------------------------------- status / sources
            Item {
                id: footer
                width: parent.width
                height: 24

                Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: Theme.border }

                Row {
                    anchors { left: parent.left; leftMargin: Theme.s2; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                    spacing: Theme.s2
                    Text {
                        text: Keybinds.runtimeState === "ok" ? "✓ checked against Hyprland"
                            : Keybinds.runtimeState === "unavailable" ? "Hyprland check unavailable"
                            : "checking…"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: Keybinds.runtimeState === "ok" ? Theme.teal : Theme.muted
                    }
                    Text {
                        text: "·  updated " + Keybinds.updatedAt
                        visible: Keybinds.updatedAt !== ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: Theme.muted
                    }
                }

                Item {
                    id: infoBtn
                    anchors { right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                    width: infoText.implicitWidth
                    height: parent.height
                    Text {
                        id: infoText
                        anchors.verticalCenter: parent.verticalCenter
                        text: Keybinds.fileList.length + (Keybinds.fileList.length === 1 ? " file" : " files")
                              + (Keybinds.warnings.length > 0 ? "  ⚠ " + Keybinds.warnings.length : "")
                              + (root.infoOpen ? "  ▴" : "  ▾")
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: Keybinds.warnings.length > 0 ? Theme.amber : (infoArea.containsMouse ? Theme.text : Theme.muted)
                    }
                    MouseArea {
                        id: infoArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.infoOpen = !root.infoOpen
                    }
                }
            }

            // files read + anything it could not follow
            Column {
                visible: root.infoOpen
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.infoOpen ? Keybinds.fileList : []
                    delegate: Text {
                        required property var modelData
                        width: col.width
                        textFormat: Text.PlainText
                        elide: Text.ElideMiddle
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: modelData.status === "ok" ? Theme.text2 : Theme.amber
                        text: (modelData.status === "ok" ? "✓ " : "⚠ ") + modelData.path
                              + "   " + (modelData.status === "ok" ? modelData.binds + " binds" : modelData.status)
                    }
                }
                Repeater {
                    model: root.infoOpen ? Keybinds.warnings : []
                    delegate: Text {
                        required property var modelData
                        width: col.width
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.amber
                        text: "⚠ " + BP.baseName(modelData.file) + ":" + modelData.line + "  " + modelData.msg
                    }
                }
                Repeater {
                    model: root.infoOpen ? Keybinds.notes : []
                    delegate: Text {
                        required property var modelData
                        width: col.width
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                        text: "· " + BP.baseName(modelData.file) + ":" + modelData.line + "  " + modelData.msg
                    }
                }
                Text {
                    visible: root.infoOpen && Keybinds.runtimeOnly > 0
                    width: col.width
                    wrapMode: Text.Wrap
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    color: Theme.teal
                    text: Keybinds.runtimeOnly + " shortcut(s) are active in Hyprland but could not be traced to a line in your files "
                          + "(they are built while Hyprland runs). They are listed as “Hyprland only”."
                }
                Item { width: 1; height: 2 }
            }
        }
    }
}
