import QtQuick
import Quickshell
import Quickshell.Widgets

// KURENAI launcher with four tabs. The host (this file) owns the search field, the tab strip and the keys;
// each tab is its own view, loaded only while it is the active one:
//   Apps   LauncherList (mode "apps")    your desktop entries
//   Run    LauncherRun                   type a command, or pick from history / programs on PATH
//   Prime  LauncherList (mode "prime")   the same apps, started through `prime-run` (NVIDIA)
//   Walls  LauncherWalls                 wallpaper thumbnails; Enter sets one with awww
//
//   Tab / Shift+Tab  next / previous tab        Ctrl+1 .. Ctrl+4   jump to a tab
//   type             filter                     Up/Down, Ctrl+N/P, Ctrl+J/K   move   (Walls: arrows move in the grid)
//   Enter            run / launch / set         Shift+Enter        alternate (Run: in terminal, Walls: set and stay open)
//   Ctrl+F           favourite (Run: forget)    Ctrl+E             Run: edit the row, Walls: big preview
//   Esc              close (Walls: closes the preview first)      click outside   close
// Opened from Hyprland with: qs -c kurenai ipc call launcher toggle|toggleTab <tab>
PanelOverlay {
    id: root

    open: UiState.launcherOpen
    place: "top-center"
    layerName: "kurenai-launcher"
    onDismissed: UiState.launcherOpen = false

    readonly property var tabs: [
        { id: "apps",  label: "Apps",  placeholder: "Search applications" },
        { id: "run",   label: "Run",   placeholder: "Run a command" },
        { id: "prime", label: "Prime", placeholder: "Search applications to run on the NVIDIA GPU" },
        { id: "walls", label: "Walls", placeholder: "Filter wallpapers by name or folder" }
    ]
    readonly property string tab: UiState.launcherTab
    readonly property int tabIndex: {
        for (let i = 0; i < tabs.length; i++) if (tabs[i].id === tab) return i;
        return 0;
    }

    function setTab(id) {
        UiState.launcherTab = id;
        input.forceActiveFocus();
    }
    function cycleTab(d) {
        setTab(tabs[(tabIndex + d + tabs.length) % tabs.length].id);
    }

    // fresh state every time it opens
    onOpenChanged: {
        if (open) {
            input.text = "";
            // the layer surface is mapped a moment after `open` flips; focus once it is
            Qt.callLater(() => {
                input.forceActiveFocus();
                if (view.item) view.item.reset();
            });
        }
    }

    // docked = hangs from the bar with concave fillets; otherwise (fullscreen window, or
    // Config.launcherDocked = false) it is the old floating card.
    docked: Config.launcherDocked && !Compositor.fullscreen
    readonly property int fillet: Theme.rLg

    Item {
        id: panel
        // docked: the fillets add `fillet` px of width on each side of the panel body
        width: Theme.launcherWidth + (root.docked ? 2 * root.fillet : 0)
        height: body.height

        Surface {                      // floating card
            visible: !root.docked
            anchors.fill: parent
        }
        DockShape {                    // docked silhouette
            visible: root.docked
            anchors.fill: parent
            fillet: root.fillet
        }

        MouseArea {                    // clicks on the panel must not reach "click outside = close"
            anchors.fill: body
            acceptedButtons: Qt.AllButtons
            onClicked: m => m.accepted = true
        }

        Item {
            id: body
            x: root.docked ? root.fillet : 0
            width: Theme.launcherWidth
            height: (Theme.s3 + 2) + bar.height + Theme.s2 + tabStrip.height + Theme.s1 + listArea.height + footer.height

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
                    text: root.tab === "run" ? ">" : Theme.icons.search
                    font.family: root.tab === "run" ? Theme.fontMono : Theme.fontIcon
                    font.pixelSize: root.tab === "run" ? Theme.fsBase + 2 : Theme.fsIcon
                    font.weight: root.tab === "run" ? Font.Bold : Font.Normal
                    color: input.activeFocus ? Theme.accentText : Theme.muted
                }

                TextInput {
                    id: input
                    anchors { left: glyph.right; right: seal.left; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    font.family: root.tab === "run" ? Theme.fontMono : Theme.fontUi
                    font.pixelSize: Theme.fsBase + 2
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.inkOnAccent
                    cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                    clip: true
                    focus: true

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        const shift = e.modifiers & Qt.ShiftModifier;
                        const v = view.item;

                        // ---- tabs (work on every tab) ----
                        if (e.key === Qt.Key_Tab) { root.cycleTab(1); e.accepted = true; return; }
                        if (e.key === Qt.Key_Backtab) { root.cycleTab(-1); e.accepted = true; return; }
                        if (ctrl && e.key >= Qt.Key_1 && e.key < Qt.Key_1 + root.tabs.length) {
                            root.setTab(root.tabs[e.key - Qt.Key_1].id);
                            e.accepted = true;
                            return;
                        }
                        if (!v) return;

                        // Esc: a tab may use it first (the wallpaper preview); otherwise it closes the launcher
                        if (e.key === Qt.Key_Escape) { if (v.back()) e.accepted = true; return; }

                        const grid = root.tab === "walls";
                        if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_N || e.key === Qt.Key_J))) {
                            v.move(0, 1); e.accepted = true;
                        } else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_P || e.key === Qt.Key_K))) {
                            v.move(0, -1); e.accepted = true;
                        } else if (grid && e.key === Qt.Key_Left) {
                            v.move(-1, 0); e.accepted = true;
                        } else if (grid && e.key === Qt.Key_Right) {
                            v.move(1, 0); e.accepted = true;
                        } else if (e.key === Qt.Key_PageDown) {
                            v.page(1); e.accepted = true;
                        } else if (e.key === Qt.Key_PageUp) {
                            v.page(-1); e.accepted = true;
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            v.activate(!!shift); e.accepted = true;
                        } else if (ctrl && e.key === Qt.Key_F) {
                            v.star(); e.accepted = true;
                        } else if (ctrl && e.key === Qt.Key_E) {
                            v.expand(); e.accepted = true;
                        } else if (grid && e.key === Qt.Key_Space && !ctrl && v.spaceKey()) {
                            e.accepted = true;     // Space on an empty filter = preview; otherwise it types a space
                        }
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.tabs[root.tabIndex].placeholder
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
                        text: "紅"
                        font.family: Theme.fontDisplay
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: Theme.inkOnAccent
                    }
                }
            }

            // ---- tab strip -------------------------------------------------------------------------
            Row {
                id: tabStrip
                anchors { top: bar.bottom; left: parent.left; right: parent.right; topMargin: Theme.s2; leftMargin: Theme.s3; rightMargin: Theme.s3 }
                height: 28
                spacing: Theme.s1

                Repeater {
                    model: root.tabs
                    delegate: Item {
                        id: tabBtn
                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.tabIndex
                        width: (tabStrip.width - tabStrip.spacing * (root.tabs.length - 1)) / root.tabs.length
                        height: tabStrip.height

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.rSm
                            color: tabBtn.active ? Theme.raised : (hover.containsMouse ? Theme.surface : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: tabBtn.modelData.label
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase
                            font.weight: tabBtn.active ? Font.DemiBold : Font.Normal
                            color: tabBtn.active ? Theme.text : Theme.muted
                        }
                        Rectangle {      // vermilion rule under the active tab
                            visible: tabBtn.active
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            width: parent.width - Theme.s6
                            height: 2
                            radius: 1
                            color: Theme.accent
                        }
                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setTab(tabBtn.modelData.id)
                        }
                    }
                }
            }

            // ---- the active tab ----------------------------------------------------------------------
            Item {
                id: listArea
                anchors { top: tabStrip.bottom; left: parent.left; right: parent.right; topMargin: Theme.s1; leftMargin: Theme.s2; rightMargin: Theme.s2 }
                height: view.item ? view.item.areaHeight : 96

                Loader {
                    id: view
                    anchors.fill: parent
                    // unloaded shortly after the panel has faded out, so thumbnails do not stay in memory
                    active: root.visible
                    sourceComponent: root.tab === "run" ? runC
                                   : root.tab === "prime" ? primeC
                                   : root.tab === "walls" ? wallsC : appsC
                }
                Component { id: appsC;  LauncherList { mode: "apps";  query: input.text } }
                Component { id: primeC; LauncherList { mode: "prime"; query: input.text } }
                Component {
                    id: runC
                    LauncherRun {
                        query: input.text
                        onEditRequested: t => { input.text = t; input.cursorPosition = t.length; }
                    }
                }
                Component { id: wallsC; LauncherWalls { query: input.text } }
            }

            // ---- key hints ---------------------------------------------------------------------------------
            Item {
                id: footer
                anchors { top: listArea.bottom; left: parent.left; right: parent.right }
                height: 30
                Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3 } height: 1; color: Theme.border }
                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: Theme.s4; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 }
                    elide: Text.ElideRight
                    text: view.item ? view.item.hint : ""
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall - 1
                    color: Theme.muted
                }
            }
        }
    }
}
