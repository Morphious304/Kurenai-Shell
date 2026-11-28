import QtQuick

// "icon button + slider + percentage (+ expand chevron)": volume, microphone, brightness.
// When `available` is false the row is dimmed and `unavailableText` says why.
Column {
    id: root

    property string caption: ""
    property string icon: ""
    property bool muted: false
    property bool showMute: true
    property real value: 0
    property bool available: true
    property string unavailableText: ""
    property bool expandable: false
    property bool expanded: false

    signal muteClicked()
    signal moved(real value)
    signal expandToggled()

    spacing: 2

    Text {
        visible: root.caption !== ""
        text: root.caption
        textFormat: Text.PlainText
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
        font.letterSpacing: 0.5
        color: Theme.muted
    }

    Row {
        id: row
        width: root.width
        height: 32
        spacing: Theme.s2

        Btn {
            visible: root.showMute
            width: 32
            height: 32
            flat: true
            center: true
            enabled: root.available
            icon: root.icon
            iconColor: root.muted ? Theme.muted : Theme.text
            onClicked: root.muteClicked()
        }
        Text {                      // no mute action (brightness): just a label glyph
            visible: !root.showMute
            width: 32
            height: 32
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.icon
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fsIcon
            color: root.available ? Theme.text : Theme.muted
        }

        KSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - 32 - 42 - (root.expandable ? 30 + row.spacing : 0) - row.spacing * 2
            enabled: root.available
            value: root.value
            fillColor: root.muted ? Theme.muted : Theme.accent
            onMoved: v => root.moved(v)
        }

        Text {
            width: 42
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignRight
            text: !root.available ? "--" : root.muted ? "mute" : Math.round(root.value * 100) + "%"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall + 1
            color: root.muted || !root.available ? Theme.muted : Theme.text
        }

        Btn {
            visible: root.expandable
            width: 30
            height: 32
            flat: true
            center: true
            icon: root.expanded ? Theme.icons.chevUp : Theme.icons.chevDown
            iconSize: 11
            onClicked: root.expandToggled()
        }
    }

    Text {
        visible: !root.available && root.unavailableText !== ""
        width: root.width
        text: root.unavailableText
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSmall
        color: Theme.muted
    }
}
