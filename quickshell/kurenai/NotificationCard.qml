import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification, used both for the transient popup and for the history list in the centre.
//   popup: true   -> auto-hides (never for critical), close button only hides the popup
//   popup: false  -> history entry, close button dismisses it for good
//
// ALL text comes from other programs, so every Text is PlainText: notification content can
// never inject markup or commands into the shell.
Rectangle {
    id: card

    required property var notif
    property bool popup: true
    // Quickshell notification object may be destroyed a moment before this delegate is.
    readonly property bool alive: !!notif

    readonly property bool critical: alive && notif.urgency === NotificationUrgency.Critical
    readonly property bool low: alive && notif.urgency === NotificationUrgency.Low

    readonly property string iconSrc: {
        if (!alive || !notif.appIcon) return "";
        const i = notif.appIcon;
        if (i.startsWith("/") || i.startsWith("file:") || i.startsWith("image:")) return i;
        return Quickshell.iconPath(i);
    }

    readonly property var actionList: {
        const out = [];
        if (!alive) return out;
        const a = notif.actions;
        for (let i = 0; i < a.length; i++) {
            if (a[i].identifier !== "default" && a[i].text !== "") out.push(a[i]);
        }
        return out;
    }
    function defaultAction() {
        if (!alive) return null;
        const a = notif.actions;
        for (let i = 0; i < a.length; i++) if (a[i].identifier === "default") return a[i];
        return null;
    }

    readonly property int timeoutMs: {
        if (alive && notif.expireTimeout > 0)
            return Math.max(3000, Math.min(20000, Math.round(notif.expireTimeout * 1000)));
        return low ? Config.popupTimeoutLow : Config.popupTimeoutNormal;
    }

    function closeThis() {
        if (!alive) return;
        if (popup) expirePopup();
        else NotificationStore.dismiss(notif);
    }
    function expirePopup() {
        if (!alive) return;
        if (notif.transient) notif.expire();            // transient = never kept in history
        else NotificationStore.hidePopup(notif.id);
    }

    implicitWidth: Theme.notifWidth
    implicitHeight: body.implicitHeight + Theme.s3 * 2
    radius: Theme.rMd
    color: area.containsMouse ? Qt.lighter(Glass.panelBg, 1.12) : Glass.panelBg
    border.width: 1
    border.color: critical ? Theme.accent : Theme.panelBorder
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    // urgency rule on the left edge: vermilion = critical, teal = normal, none = low
    Rectangle {
        visible: !card.low
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: Theme.s2; bottomMargin: Theme.s2 }
        width: 3
        radius: 1.5
        color: card.critical ? Theme.accent : Theme.teal
    }

    // auto-hide (popups only; critical notifications stay until dismissed; hover pauses)
    Timer {
        interval: card.timeoutMs
        running: card.popup && card.alive && !card.critical && !area.containsMouse
        onTriggered: card.expirePopup()
    }

    // click the body = the app's default action (if any); middle click = dismiss from view
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        z: -1
        onClicked: m => {
            if (m.button === Qt.MiddleButton) { card.closeThis(); return; }
            const d = card.defaultAction();
            if (d) { d.invoke(); card.expirePopup(); }
        }
    }

    Row {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.s3 }
        anchors.leftMargin: Theme.s3 + 3
        spacing: Theme.s3

        // ---- app icon (or a rose initial tile when the app has none) -----------------
        Item {
            width: 32
            height: 32
            IconImage {
                visible: card.iconSrc !== ""
                anchors.fill: parent
                source: card.iconSrc
            }
            Rectangle {
                visible: card.iconSrc === ""
                anchors.fill: parent
                radius: Theme.rSm
                color: Theme.raised
                Text {
                    anchors.centerIn: parent
                    text: card.alive && card.notif.appName ? card.notif.appName.charAt(0).toUpperCase() : "!"
                    textFormat: Text.PlainText
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 2
                    font.weight: Font.Bold
                    color: Theme.rose
                }
            }
        }

        Column {
            width: parent.width - 32 - Theme.s3 - (card.alive && card.notif.image !== "" ? 48 + Theme.s3 : 0)
            spacing: Theme.s1

            // header: app name  ·  age                                [x]
            Item {
                width: parent.width
                height: 20

                Text {
                    anchors { left: parent.left; right: closeBtn.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    font.letterSpacing: 0.5
                    color: card.critical ? Theme.accentText : Theme.muted
                    text: {
                        if (!card.alive) return "";
                        const name = card.notif.appName !== "" ? card.notif.appName : "Notification";
                        const age = NotificationStore.ago(card.notif.id);
                        return age !== "" ? name + "  \u00B7  " + age : name;
                    }
                }

                Rectangle {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 20
                    height: 20
                    radius: Theme.rSm
                    color: closeArea.containsMouse ? Theme.raised : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: Theme.icons.close
                        font.family: Theme.fontIcon
                        font.pixelSize: 11
                        color: closeArea.containsMouse ? Theme.text : Theme.muted
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.closeThis()
                    }
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                text: card.alive ? card.notif.summary : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Text {
                visible: text !== ""
                width: parent.width
                text: card.alive ? card.notif.body : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 6
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                color: Theme.text2
            }

            // action buttons (the "default" action is the click on the card itself)
            Flow {
                visible: card.actionList.length > 0
                width: parent.width
                spacing: Theme.s2

                Repeater {
                    model: card.actionList
                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        height: 26
                        width: label.implicitWidth + Theme.s4 * 2
                        radius: Theme.rSm
                        color: btnArea.containsMouse ? Theme.raised : "transparent"
                        border.width: 1
                        border.color: btnArea.containsMouse ? Theme.teal : Theme.borderStrong
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: btn.modelData.text
                            textFormat: Text.PlainText
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSmall + 1
                            font.weight: Font.Medium
                            color: Theme.teal
                        }
                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { btn.modelData.invoke(); card.expirePopup(); }
                        }
                    }
                }
            }
        }

        // notification image (e.g. a chat avatar), if the app sent one
        Image {
            visible: card.alive && card.notif.image !== ""
            width: 48
            height: 48
            source: card.alive ? card.notif.image : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(96, 96)
        }
    }
}
