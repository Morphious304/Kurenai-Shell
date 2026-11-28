import QtQuick
import Quickshell

// The clipboard manager. Open it with SUPER+V or: qs -c kurenai ipc call clipboard toggle
//
//   History tab   everything you copied (text and images), newest first, auto-deleted after
//                 Config.clipboardRetentionDays days
//   Pinned tab    items you chose to keep: stored separately, never auto-deleted
//
//   Enter     copy the selected entry back onto the clipboard (then paste in your app with Ctrl+V as usual)
//   Ctrl+P    pin / unpin          Shift+Delete    delete the entry (or Delete on an empty search)
//   Tab       switch tab           Up/Down, Ctrl+J/K  move          Esc  close
//
// This panel never pastes by itself and never binds Ctrl+X/C/V: those belong to your applications.
PanelOverlay {
    id: root

    open: UiState.clipboardOpen
    place: "top-center"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-clipboard"
    onDismissed: UiState.clipboardOpen = false

    property string tab: "history"           // history | pinned
    property string confirm: ""              // "" | "wipe" | "unpin"   (waiting for an explicit second click)
    readonly property bool onHistory: tab === "history"

    onOpenChanged: {
        if (open) {
            input.text = "";
            tab = "history";
            confirm = "";
            list.currentIndex = 0;
            Clipboard.refresh();
            Clipboard.purge();
            Qt.callLater(() => input.forceActiveFocus());
        } else {
            confirm = "";
            Clipboard.clearThumbs();          // decoded image previews are removed as soon as you close the panel
        }
    }

    readonly property var shown: {
        const src = onHistory ? Clipboard.entries : Clipboard.pins;
        const q = input.text.trim().toLowerCase();
        if (q === "") return src;
        return src.filter(e => e.preview.toLowerCase().indexOf(q) >= 0 || (e.kind === "image" && "image".indexOf(q) >= 0));
    }
    // list height from the data (not from the list itself, so sizing never loops)
    readonly property real listH: {
        let h = 0;
        const n = Math.min(shown.length, 7);
        for (let i = 0; i < n; i++) h += shown[i].kind === "image" ? 88 : 52;
        return Math.max(120, Math.min(h, 440));
    }

    function currentEntry() { return shown[list.currentIndex]; }
    function copyCurrent() {
        const e = currentEntry();
        if (!e) return;
        Clipboard.copyEntry(e);
        UiState.clipboardOpen = false;
    }
    function togglePinCurrent() {
        const e = currentEntry();
        if (!e) return;
        if (e.pin) Clipboard.unpinEntry(e); else Clipboard.pinEntry(e);
    }
    function deleteCurrent() {
        const e = currentEntry();
        if (e) Clipboard.deleteEntry(e);
    }
    function switchTab() {
        tab = onHistory ? "pinned" : "history";
        list.currentIndex = 0;
        confirm = "";
    }
    function age(epoch, pinned) {
        const a = Clipboard.ago(epoch);
        return pinned ? (a !== "" ? "Pinned  \u00B7  " + a : "Pinned") : a;
    }

    Timer { interval: 8000; running: root.confirm !== ""; onTriggered: root.confirm = "" }    // a forgotten prompt cancels itself

    PanelFrame {
        docked: root.docked
        bodyWidth: 640
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s2

            // ---------------------------------------------------------------- tabs + recording switch
            Item {
                width: parent.width
                height: 34

                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Btn {
                        width: 128; height: 32; center: true
                        text: "History  " + Clipboard.entries.length
                        checked: root.onHistory
                        onClicked: { root.tab = "history"; list.currentIndex = 0; root.confirm = ""; }
                    }
                    Btn {
                        width: 128; height: 32; center: true
                        text: "Pinned  " + Clipboard.pins.length
                        checked: !root.onHistory
                        onClicked: { root.tab = "pinned"; list.currentIndex = 0; root.confirm = ""; }
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Clipboard.paused ? "Paused" : "Recording"
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall + 1
                        font.weight: Clipboard.paused ? Font.DemiBold : Font.Normal
                        color: Clipboard.paused ? Theme.accentText : Theme.muted
                    }
                    KToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !Clipboard.paused
                        enabled: Clipboard.ready
                        onToggled: Clipboard.setPaused(!Clipboard.paused)
                    }
                }
            }

            Text {
                visible: Clipboard.paused && Clipboard.ready
                width: parent.width
                text: "Paused: nothing you copy is being recorded."
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall + 1
                color: Theme.accentText
            }

            // ---------------------------------------------------------------- search
            Rectangle {
                width: parent.width
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
                    anchors { left: glyph.right; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 2
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.inkOnAccent
                    cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                    clip: true
                    focus: true
                    onTextChanged: list.currentIndex = 0

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        const shift = e.modifiers & Qt.ShiftModifier;
                        if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_N || e.key === Qt.Key_J))) {
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1); e.accepted = true;
                        } else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_K))) {
                            list.currentIndex = Math.max(0, list.currentIndex - 1); e.accepted = true;
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            root.copyCurrent(); e.accepted = true;
                        } else if (ctrl && e.key === Qt.Key_P) {
                            root.togglePinCurrent(); e.accepted = true;
                        } else if ((shift && e.key === Qt.Key_Delete) || (e.key === Qt.Key_Delete && input.text === "")) {
                            root.deleteCurrent(); e.accepted = true;
                        } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            root.switchTab(); e.accepted = true;
                        }
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.onHistory ? "Search clipboard history" : "Search pinned items"
                        font: input.font
                        color: Theme.muted
                    }
                }
            }

            // ---------------------------------------------------------------- the list
            Item {
                width: parent.width
                height: root.listH

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    visible: root.shown.length > 0 && Clipboard.ready
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 90
                    currentIndex: 0
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    model: ScriptModel { values: root.shown }

                    highlight: Rectangle {
                        radius: Theme.rMd
                        color: Theme.raised
                        Rectangle {
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
                        readonly property bool isImage: modelData.kind === "image"
                        // history images are decoded on demand (Clipboard.requestThumb); a pinned image is its own file
                        readonly property string thumb: !isImage ? ""
                            : modelData.pin ? "file://" + encodeURI(Clipboard.pinDir + "/" + modelData.id + ".bin")
                            : Clipboard.thumbReady[modelData.id] === true ? "file://" + encodeURI(Clipboard.thumbPath(modelData.id)) : ""

                        width: list.width
                        height: isImage ? 88 : 52
                        Component.onCompleted: { if (isImage && !modelData.pin) Clipboard.requestThumb(modelData.id); }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = row.index
                            onClicked: { list.currentIndex = row.index; root.copyCurrent(); }
                        }

                        Row {
                            anchors { fill: parent; leftMargin: Theme.s4; rightMargin: Theme.s2 }
                            spacing: Theme.s3

                            Item {
                                width: row.isImage ? 76 : 28
                                height: parent.height
                                Image {
                                    visible: row.thumb !== ""
                                    anchors.centerIn: parent
                                    width: 72
                                    height: 72
                                    source: row.thumb
                                    sourceSize: Qt.size(144, 144)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Text {
                                    visible: row.thumb === ""
                                    anchors.centerIn: parent
                                    text: row.isImage ? Theme.icons.image : Theme.icons.file
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 18
                                    color: Theme.muted
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - (row.isImage ? 76 : 28) - 64 - Theme.s3 * 2
                                spacing: 2
                                Text {
                                    width: parent.width
                                    // everything shown comes from other programs: plain text only
                                    textFormat: Text.PlainText
                                    text: row.isImage
                                        ? "Image  " + row.modelData.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                                        : row.modelData.preview
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsBase
                                    color: Theme.text
                                }
                                Text {
                                    visible: text !== ""
                                    text: root.age(row.modelData.epoch, row.modelData.pin)
                                    textFormat: Text.PlainText
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsSmall
                                    color: row.modelData.pin ? Theme.amber : Theme.muted
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Btn {
                                    width: 32; height: 32; flat: true; center: true
                                    icon: Theme.icons.pin
                                    iconColor: row.modelData.pin ? Theme.amber : Theme.text2
                                    onClicked: { if (row.modelData.pin) Clipboard.unpinEntry(row.modelData); else Clipboard.pinEntry(row.modelData); }
                                }
                                Btn {
                                    width: 32; height: 32; flat: true; center: true
                                    icon: Theme.icons.trash
                                    onClicked: Clipboard.deleteEntry(row.modelData)
                                }
                            }
                        }
                    }
                }

                // ---- empty / unavailable states
                Column {
                    visible: !(root.shown.length > 0 && Clipboard.ready)
                    anchors.centerIn: parent
                    width: parent.width - Theme.s6
                    spacing: Theme.s2
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase + 1
                        font.weight: Font.DemiBold
                        color: Theme.text2
                        text: !Clipboard.enabled ? "Clipboard history is turned off"
                            : !Clipboard.toolsOk ? "Clipboard history needs a little setup"
                            : input.text.trim() !== "" ? "No entries match your search"
                            : root.onHistory ? "Nothing recorded yet" : "Nothing pinned yet"
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall + 1
                        color: Theme.muted
                        text: !Clipboard.enabled ? "Set clipboardEnabled to true in Config.qml to record your clipboard."
                            : !Clipboard.toolsOk ? "Install cliphist and wl-clipboard (sudo pacman -S cliphist wl-clipboard) and run install.sh, then kurenai-ctl restart."
                            : input.text.trim() !== "" ? ""
                            : root.onHistory ? (Clipboard.paused ? "Recording is paused: switch it on above." : "Copy some text or an image and it appears here.")
                              : "Pin an entry with the pin button or Ctrl+P to keep it past the automatic clean-up."
                    }
                }
            }

            // ---------------------------------------------------------------- confirmation (never a one-click wipe)
            Item {
                visible: root.confirm !== ""
                width: parent.width
                height: 44
                Text {
                    anchors { left: parent.left; right: confirmRow.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    wrapMode: Text.Wrap
                    text: root.confirm === "wipe" ? "Delete all " + Clipboard.entries.length + " history entries? Pinned items are kept."
                                                  : "Remove all " + Clipboard.pins.length + " pinned items?"
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                    font.weight: Font.DemiBold
                    color: Theme.accentText
                }
                Row {
                    id: confirmRow
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s2
                    Btn { width: 90; height: 32; center: true; text: "Cancel"; onClicked: root.confirm = "" }
                    Btn {
                        width: 110; height: 32; center: true
                        text: root.confirm === "wipe" ? "Delete all" : "Remove all"
                        checked: true
                        onClicked: {
                            if (root.confirm === "wipe") Clipboard.wipeHistory(); else Clipboard.unpinAll();
                            root.confirm = "";
                        }
                    }
                }
            }

            // ---------------------------------------------------------------- footer
            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Item {
                width: parent.width
                height: 40
                Column {
                    anchors { left: parent.left; right: clearBtn.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: "\u21B5 copy   Ctrl+P pin   Shift+Del delete   Tab switch   (paste with Ctrl+V in your app)"
                        elide: Text.ElideRight
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsSmall - 1
                        color: Theme.muted
                    }
                    Text {
                        width: parent.width
                        text: "History is deleted after " + Config.clipboardRetentionDays + " days. Pinned items stay."
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        color: Theme.muted
                    }
                }
                Btn {
                    id: clearBtn
                    visible: Clipboard.ready && (root.onHistory ? Clipboard.entries.length > 0 : Clipboard.pins.length > 0)
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 130; height: 30; flat: true; center: true
                    icon: Theme.icons.trash
                    text: root.onHistory ? "Clear history\u2026" : "Remove pins\u2026"
                    onClicked: root.confirm = root.onHistory ? "wipe" : "unpin"
                }
            }
        }
    }
}
