import QtQuick
import Quickshell
import Quickshell.Wayland

// The on-screen display: one small pill, bottom-centre of the focused monitor, click-through, never
// takes focus. All content comes from OsdState (which reads the real values), see there.
PanelWindow {
    id: win

    screen: Compositor.focusedScreen
    visible: OsdState.shown || pill.opacity > 0.01

    anchors { bottom: true }
    margins { bottom: 56 }
    implicitWidth: 300
    implicitHeight: 56

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "kurenai-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}          // empty region: every click goes to the window underneath

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.rLg
        color: Glass.panelBg
        border.width: 1
        border.color: Theme.panelBorder

        opacity: OsdState.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }

        // small vermilion rule on the left edge, same accent language as the notification cards
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: Theme.s3; bottomMargin: Theme.s3 }
            width: 3
            radius: 1.5
            color: OsdState.muted ? Theme.muted : Theme.accent
        }

        Text {
            id: glyph
            anchors { left: parent.left; leftMargin: Theme.s4 + 4; verticalCenter: parent.verticalCenter }
            width: 24
            horizontalAlignment: Text.AlignHCenter
            text: OsdState.icon
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fsIcon + 6
            color: OsdState.muted ? Theme.muted : Theme.text
        }

        // level bar (volume, brightness)
        Column {
            visible: OsdState.level >= 0
            anchors { left: glyph.right; leftMargin: Theme.s3; right: parent.right; rightMargin: Theme.s4; verticalCenter: parent.verticalCenter }
            spacing: 6

            Row {
                width: parent.width
                Text {
                    width: parent.width - pct.implicitWidth
                    text: OsdState.title
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    font.letterSpacing: 0.5
                    color: Theme.muted
                }
                Text {
                    id: pct
                    text: OsdState.detail
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsSmall + 1
                    color: OsdState.muted ? Theme.muted : Theme.text
                }
            }
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderStrong
                Rectangle {
                    width: Math.max(0, Math.min(1, OsdState.level)) * parent.width
                    height: parent.height
                    radius: 3
                    color: OsdState.muted ? Theme.muted : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                }
            }
        }

        // text-only (mic, media)
        Column {
            visible: OsdState.level < 0
            anchors { left: glyph.right; leftMargin: Theme.s3; right: parent.right; rightMargin: Theme.s4; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text {
                width: parent.width
                text: OsdState.title
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase + 1
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                visible: text !== ""
                width: parent.width
                text: OsdState.detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall + 1
                color: OsdState.muted ? Theme.accentText : Theme.text2
            }
        }
    }
}
