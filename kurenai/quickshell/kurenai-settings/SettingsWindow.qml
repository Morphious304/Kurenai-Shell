import QtQuick

// The whole window: sidebar, search, the open page, the Output drawer, and a toast.
Item {
    id: win
    focus: true

    readonly property int sideW: 236

    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (ctrl && e.key === Qt.Key_K) { searchBox.focusInput(); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_Q) { Qt.quit(); e.accepted = true; }
        else if (ctrl && e.key === Qt.Key_J) { App.drawerOpen = !App.drawerOpen; e.accepted = true; }
        else if (e.key === Qt.Key_Escape) {
            if (App.query !== "") App.query = "";
            else if (App.drawerOpen) App.drawerOpen = false;
            e.accepted = true;
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.bg }

    // ------------------------------------------------------------------ sidebar
    Rectangle {
        id: side
        width: win.sideW
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        color: Theme.surface
        Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.border }

        Item {
            id: brand
            x: Theme.s4; y: Theme.s4
            width: parent.width - Theme.s4 * 2
            height: 48
            Text {
                id: seal
                anchors.verticalCenter: parent.verticalCenter
                text: "紅"
                font.family: Theme.fontDisplay
                font.pixelSize: 34
                color: Theme.accentText
            }
            Column {
                anchors { left: seal.right; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                Text { text: "KURENAI"; font.family: Theme.fontUi; font.pixelSize: Theme.fsBase + 2; font.weight: Font.Bold; font.letterSpacing: 2; color: Theme.text }
                Text { text: "Settings"; font.family: Theme.fontUi; font.pixelSize: Theme.fsSmall + 1; color: Theme.muted }
            }
        }

        Flickable {
            id: navFlick
            anchors { left: parent.left; right: parent.right; top: brand.bottom; bottom: sideFoot.top; topMargin: Theme.s3; bottomMargin: Theme.s2 }
            contentWidth: width
            contentHeight: nav.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: nav
                x: Theme.s3
                width: navFlick.width - Theme.s3 * 2
                spacing: 2
                Repeater {
                    model: App.pages
                    Column {
                        id: navItem
                        required property var modelData
                        required property int index
                        width: nav.width
                        spacing: 2
                        Text {
                            visible: navItem.index === 0 || App.pages[navItem.index - 1].section !== navItem.modelData.section
                            topPadding: navItem.index === 0 ? 0 : Theme.s3
                            text: navItem.modelData.section.toUpperCase()
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSmall - 1
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                            color: Theme.muted
                            leftPadding: Theme.s2
                            height: visible ? implicitHeight : 0
                        }
                        Btn {
                            width: parent.width
                            implicitHeight: 34
                            flat: true
                            icon: navItem.modelData.icon
                            text: navItem.modelData.title
                            checked: App.page === navItem.modelData.id
                            onClicked: App.go(navItem.modelData.id)
                        }
                    }
                }
            }
        }

        Item {
            id: sideFoot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 56
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.border }
            Row {
                x: Theme.s4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s2
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Store.status.shell && Store.status.shell.running ? Theme.teal : Theme.muted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Store.statusLoaded ? "Checking..." : (Store.status.shell && Store.status.shell.running ? "Shell is running" : "Shell is stopped")
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall + 1
                    color: Theme.text2
                }
            }
        }
    }

    // ------------------------------------------------------------------ main area
    Item {
        id: main
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        Item {
            id: topbar
            x: Theme.s4; y: Theme.s3
            width: parent.width - Theme.s4 * 2
            height: 40

            Rectangle {
                id: searchBox
                anchors { left: parent.left; right: outBtn.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                height: 36
                radius: Theme.rMd
                color: Theme.surface
                border.width: 1
                border.color: sinput.activeFocus ? Theme.accent : Theme.border
                function focusInput() { sinput.forceActiveFocus(); sinput.selectAll(); }

                Text {
                    id: sglyph
                    anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    text: Theme.icons.search
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fsIcon
                    color: sinput.activeFocus ? Theme.accentText : Theme.muted
                }
                TextInput {
                    id: sinput
                    anchors { left: sglyph.right; right: hint.left; leftMargin: Theme.s3; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.inkOnAccent
                    selectByMouse: true
                    clip: true
                    cursorDelegate: Rectangle { width: 2; color: Theme.accent }
                    onTextChanged: if (App.query !== text) App.query = text
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Down) { results.move(1); e.accepted = true; }
                        else if (e.key === Qt.Key_Up) { results.move(-1); e.accepted = true; }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { results.open(); win.forceActiveFocus(); e.accepted = true; }
                        else if (e.key === Qt.Key_Escape) { App.query = ""; win.forceActiveFocus(); e.accepted = true; }
                    }
                    Text {
                        visible: sinput.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search settings and pages"
                        font: sinput.font
                        color: Theme.muted
                    }
                }
                Text {
                    id: hint
                    anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                    text: "Ctrl+K"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall
                    color: Theme.muted
                }
                Connections {
                    target: App
                    function onQueryChanged() { if (App.query === "" && sinput.text !== "") sinput.text = ""; }
                }
            }

            Btn {
                id: outBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 112
                implicitHeight: 36
                height: 36
                center: true
                icon: Theme.icons.sliders === undefined ? "" : ""
                text: Cli.busy ? "Working..." : "Output"
                checked: App.drawerOpen
                onClicked: App.drawerOpen = !App.drawerOpen
            }
        }

        // the open page
        Loader {
            id: pageLoader
            anchors { left: parent.left; right: parent.right; top: topbar.bottom; topMargin: Theme.s2; bottom: drawer.visible ? drawer.top : parent.bottom }
            source: App.current.file
            onStatusChanged: if (status === Loader.Error) console.warn("[kurenai-settings] could not load", App.current.file)
        }

        // a page that fails to load says so, instead of showing an empty window
        Text {
            visible: pageLoader.status === Loader.Error
            anchors.centerIn: pageLoader
            width: pageLoader.width - Theme.s6 * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "This page could not be loaded (" + App.current.file + "). Run the window from a terminal to see why:  qs -c kurenai-settings"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBase
            color: Theme.amber
        }

        SearchPanel {
            id: results
            visible: App.query !== ""
            anchors { left: parent.left; right: parent.right; top: topbar.bottom; topMargin: Theme.s1; leftMargin: Theme.s4; rightMargin: Theme.s4 }
            height: Math.min(420, Math.max(80, results.results.length * 46 + Theme.s4))
            z: 10
        }

        Drawer {
            id: drawer
            visible: App.drawerOpen
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 250
        }

        Rectangle {
            id: toast
            visible: App.toast !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: drawer.visible ? drawer.top : parent.bottom; bottomMargin: Theme.s4 }
            width: Math.min(parent.width - Theme.s6 * 2, toastText.implicitWidth + Theme.s6)
            height: 36
            radius: 18
            color: Theme.panelBg
            border.width: 1
            border.color: App.toastError ? Theme.amber : Theme.panelBorder
            z: 20
            Text {
                id: toastText
                anchors.centerIn: parent
                width: parent.width - Theme.s4
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                text: App.toast
                textFormat: Text.PlainText
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                color: App.toastError ? Theme.amber : Theme.text
            }
        }
    }

    Connections {
        target: Cli
        function onFailed(cmd, message) { App.say(message, true); App.drawerOpen = true; }
        function onWrote() { if (App.toast === "" || !App.toastError) App.say("Applied", false); }
    }
}
