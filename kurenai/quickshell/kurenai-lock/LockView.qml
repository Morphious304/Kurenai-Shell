import QtQuick
import Quickshell
import Quickshell.Services.UPower

// One screen of the lock. Layout from the approved mock-up, scaled by u = screen height / 1080.
// Every screen shows the same state (LockState); the password field lives on whichever screen has keyboard focus.
Item {
    id: root

    property string screenName: ""

    readonly property real u: Math.max(0.5, height / 1080)
    readonly property string phase: LockState.phase
    readonly property bool idle: phase === "idle"

    // fade out on success
    opacity: LockState.unlocking ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 200 } }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ================================================================== background
    Wallpaper { anchors.fill: parent; source: LockState.wallpaperFor(root.screenName); u: root.u }

    Rectangle {      // vignette
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Qt.darker(Theme.bg, 1.8), 0.15) }
            GradientStop { position: 1.0; color: Theme.alpha(Qt.darker(Theme.bg, 1.8), 0.65) }
        }
    }
    Rectangle {      // vermilion glow along the bottom; stronger after a wrong password
        id: glowRect
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: parent.height * 0.45
        property color glow: root.phase === "wrong" || root.phase === "cooldown" ? Theme.alpha(Theme.accent, 0.30) : Theme.alpha(Theme.accent, 0.14)
        Behavior on glow { ColorAnimation { duration: 260 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha(Theme.accent, 0) }
            GradientStop { position: 1.0; color: glowRect.glow }
        }
    }

    // ================================================================== clock + interaction
    Column {
        x: 128 * root.u
        y: root.height * 0.245

        Text {
            text: "LOCKED"
            font.family: Theme.fontMono
            font.pixelSize: 22 * root.u
            font.letterSpacing: 5 * root.u
            color: Theme.muted
        }
        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.fontMono
            font.pixelSize: 214 * root.u
            font.letterSpacing: -6 * root.u
            color: Theme.text
        }
        Text {
            text: Qt.formatDate(clock.date, "dddd d MMMM")
            font.family: Theme.fontUi
            font.pixelSize: 38 * root.u
            color: Theme.text2
        }
        Item { width: 1; height: 72 * root.u }

        Item {
            id: slot
            width: 700 * root.u
            height: 210 * root.u

            // ---------------------------------------------------------------- idle: hint only
            Row {
                id: idleRow
                anchors.top: parent.top
                spacing: 28 * root.u
                opacity: root.idle ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Seal { size: 72 * root.u; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4 * root.u
                    Text {
                        text: "Press any key to unlock"
                        font.family: Theme.fontUi
                        font.pixelSize: 30 * root.u
                        color: Theme.text2
                    }
                    Text {
                        visible: LockState.fpState === "ready"
                        text: "or use your fingerprint"
                        font.family: Theme.fontUi
                        font.pixelSize: 24 * root.u
                        color: Theme.muted
                    }
                }
            }

            // ---------------------------------------------------------------- input pill + status
            Column {
                id: inputBlock
                anchors.top: parent.top
                spacing: 22 * root.u
                opacity: root.idle ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Rectangle {
                    id: pill
                    width: 700 * root.u
                    height: 96 * root.u
                    radius: 24 * root.u
                    color: Theme.alpha(Theme.surface, 0.94)
                    border.width: Math.max(1, 2 * root.u)
                    border.color: root.phase === "wrong" || root.phase === "cooldown" ? Theme.accent
                                : root.phase === "verifying" ? Theme.teal
                                : field.activeFocus ? Theme.teal : Theme.panelBorder
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    transform: Translate { id: shakeT }

                    Seal {
                        id: seal
                        size: 60 * root.u
                        anchors { left: parent.left; leftMargin: 18 * root.u; verticalCenter: parent.verticalCenter }
                        pulse: root.phase === "verifying"
                        rotation: root.phase === "wrong" ? -7 : 0
                        Behavior on rotation { NumberAnimation { duration: 140 } }
                    }

                    // typed characters, as petals (a decorative picture, the real field is the hidden one below)
                    Row {
                        anchors { left: seal.right; leftMargin: 26 * root.u; right: hint.left; verticalCenter: parent.verticalCenter }
                        spacing: 9 * root.u
                        clip: true
                        Repeater {
                            model: Math.min(LockState.length, 16)
                            delegate: Petal { size: 40 * root.u }
                        }
                        Text {
                            visible: LockState.length === 0 && root.phase !== "verifying"
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.phase === "wrong" ? "Try again" : "Password"
                            font.family: Theme.fontUi
                            font.pixelSize: 28 * root.u
                            color: Theme.muted
                        }
                    }

                    Text {
                        id: hint
                        anchors { right: parent.right; rightMargin: 26 * root.u; verticalCenter: parent.verticalCenter }
                        text: "\u21B5"
                        font.family: Theme.fontMono
                        font.pixelSize: 26 * root.u
                        color: Theme.muted
                    }
                }

                // status line(s)
                Column {
                    spacing: 6 * root.u
                    Text {
                        id: statusText
                        width: pill.width
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: Theme.fontUi
                        font.pixelSize: 26 * root.u
                        font.weight: LockState.message !== "" || root.phase === "wrong" || root.phase === "cooldown" ? Font.DemiBold : Font.Normal
                        color: LockState.message !== "" || root.phase === "wrong" || root.phase === "cooldown" ? Theme.accentText : Theme.muted
                        text: {
                            if (LockState.message !== "") return LockState.message;
                            switch (root.phase) {
                            case "verifying": return "Checking\u2026";
                            case "wrong": return LockState.attempts > 1 ? "Incorrect password  \u00B7  " + LockState.attempts + " failed attempts" : "Incorrect password";
                            case "cooldown": return "Too many attempts. Wait " + LockState.cooldownLeft + " s";
                            case "success": return "Welcome back";
                            default: return "Enter to unlock  \u00B7  Esc to clear";
                            }
                        }
                    }
                    Text {
                        width: pill.width
                        visible: text !== ""
                        textFormat: Text.PlainText
                        font.family: Theme.fontUi
                        font.pixelSize: 22 * root.u
                        color: Theme.muted
                        text: LockState.fpState === "ready" ? "Or use your fingerprint"
                            : LockState.fpState === "retry" ? LockState.fpHint : ""
                    }
                }
            }
    
        }
    }

    // ================================================================== vertical title strip (echoes the wallpaper's band)
    Rectangle {
        x: root.width - width - 144 * root.u
        y: 120 * root.u
        width: 92 * root.u
        height: 636 * root.u
        color: Theme.alpha(Qt.darker(Theme.bg, 1.7), 0.58)
        border.width: Math.max(1, 2 * root.u)
        border.color: Theme.panelBorder

        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: Math.max(2, 4 * root.u); color: Theme.accent }

        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 48 * root.u }
            spacing: 36 * root.u
            Column {
                spacing: 2 * root.u
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: ["\u4F59", "\u6CE2"]            // 余波
                    delegate: Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        font.family: Theme.fontDisplay
                        font.pixelSize: 60 * root.u
                        color: Theme.text
                    }
                }
            }
            Column {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: ["\u30ED", "\u30C3", "\u30AF", "\u4E2D"]   // ロック中 ("locked")
                    delegate: Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        font.family: Theme.fontDisplay
                        font.pixelSize: 26 * root.u
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // ================================================================== bottom line: who/what, battery, notification COUNT
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 128 * root.u; rightMargin: 128 * root.u; bottomMargin: 68 * root.u }
        height: 40 * root.u

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 10 * root.u
            Text {
                text: Quickshell.env("USER") || ""
                font.family: Theme.fontUi
                font.pixelSize: 26 * root.u
                font.weight: Font.Medium
                color: Theme.text2
            }
            Text {
                visible: Config.deviceLabel !== ""
                text: "\u00B7  " + Config.deviceLabel
                font.family: Theme.fontUi
                font.pixelSize: 26 * root.u
                color: Theme.muted
            }
        }

        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            readonly property var bat: UPower.displayDevice
            readonly property bool hasBat: !!bat && bat.isPresent
            text: {
                const parts = [];
                if (hasBat) parts.push(Math.round(bat.percentage * 100) + "%" + (bat.state === UPowerDeviceState.Charging ? " charging" : ""));
                if (Config.showNotificationCount && LockState.notifCount > 0)
                    parts.push(LockState.notifCount + (LockState.notifCount === 1 ? " notification" : " notifications"));
                return parts.join("  \u00B7  ");
            }
            font.family: Theme.fontMono
            font.pixelSize: 24 * root.u
            color: Theme.muted
        }
    }

    // ================================================================== preview badge (so a preview is never mistaken for a lock)
    Rectangle {
        visible: LockState.preview
        x: 24 * root.u
        y: 24 * root.u
        width: previewText.implicitWidth + 28 * root.u
        height: 44 * root.u
        radius: 8 * root.u
        color: Theme.accent
        Text {
            id: previewText
            anchors.centerIn: parent
            text: "PREVIEW \u00B7 nothing is locked"
            font.family: Theme.fontMono
            font.pixelSize: 22 * root.u
            font.weight: Font.DemiBold
            color: Theme.inkOnAccent
        }
    }

    // ================================================================== keyboard: the hidden password field
    TextInput {
        id: field
        width: 1
        height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        readOnly: root.phase === "verifying" || root.phase === "cooldown" || root.phase === "success"

        onTextEdited: LockState.setPassword(text)
        // another screen got the keyboard: continue with what was typed so far
        onActiveFocusChanged: if (activeFocus) text = LockState.pending

        Keys.onReturnPressed: LockState.submit()
        Keys.onEnterPressed: LockState.submit()
        Keys.onEscapePressed: LockState.clear()
        Keys.onPressed: e => {
            LockState.touch();
            // no pasting into the password field
            if (((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) || ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert))
                e.accepted = true;
        }

        Connections {
            target: LockState
            function onClearInput() { field.text = ""; }
        }
    }
    Component.onCompleted: {
        field.forceActiveFocus();
        LockState.log("view created: screen='" + root.screenName + "' size=" + Math.round(width) + "x" + Math.round(height)
                      + " opacity=" + opacity + " phase=" + LockState.phase);
    }
    Component.onDestruction: LockState.log("view destroyed: screen='" + root.screenName + "'")

    // any pointer activity wakes the field and (re)takes the keyboard on this screen
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPositionChanged: LockState.touch()
        onPressed: { LockState.touch(); field.forceActiveFocus(); }
    }

    // wrong password: a short shake of the field
    Connections {
        target: LockState
        function onWrongCountChanged() { shake.restart(); }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeT; property: "x"; to: -22 * root.u; duration: 45 }
        NumberAnimation { target: shakeT; property: "x"; to: 22 * root.u; duration: 70 }
        NumberAnimation { target: shakeT; property: "x"; to: -12 * root.u; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 12 * root.u; duration: 60 }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50 }
    }
}
