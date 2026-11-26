import QtQuick

// The one clickable control: list rows, tiles, segmented buttons, icon buttons.
//   checked  = vermilion fill (on / selected / current)
//   enabled: false  = dimmed and inert; put the REASON in `subtext` so it is never a silent dead button
//   center   = icon/label centred in the button (segmented buttons, icon buttons)
//   stacked  = icon on top, label and subtext underneath using the full width (toggle tiles)
//   Tab focuses it (teal ring), Space/Enter activates it.
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property string subtext: ""
    property string trailing: ""          // small right-aligned text (e.g. a signal percentage)
    property bool checked: false
    property bool flat: false             // transparent until hovered (used for icon-only buttons)
    property bool center: false
    property bool stacked: false
    property color iconColor: Theme.text2
    property int iconSize: Theme.fsIcon

    signal clicked()

    readonly property bool hovered: area.containsMouse
    readonly property color fg: checked ? Theme.inkOnAccent : Theme.text
    readonly property color fg2: checked ? Theme.inkOnAccent : Theme.muted
    readonly property color glyphColor: checked ? Theme.inkOnAccent : iconColor

    implicitHeight: stacked ? 64 : subtext !== "" ? 44 : 32
    implicitWidth: 120
    radius: Theme.rMd
    opacity: enabled ? 1 : 0.55
    activeFocusOnTab: enabled

    color: checked ? Theme.accent
         : (hovered || activeFocus) ? Theme.raised
         : flat ? "transparent" : Theme.surface
    border.width: checked || flat ? 0 : 1
    border.color: Theme.border
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    function activate() { if (enabled) root.clicked(); }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()

    // Width available to the label. Computed from the button's own width and the *implicit* width of
    // its neighbours only, so no size ever depends on the label's own (final) width.
    readonly property real iconSlot: icon !== "" ? 18 + Theme.s2 : 0
    readonly property real trailingSlot: trailing !== "" ? trailingText.implicitWidth + Theme.s2 : 0
    readonly property real maxTextW: Math.max(0, width - Theme.s3 * 2 - iconSlot - trailingSlot)

    // ------------------------------------------------------------ inline layout (rows, segmented, icon buttons)
    Row {
        id: row
        visible: !root.stacked
        anchors {
            verticalCenter: parent.verticalCenter
            left: root.center ? undefined : parent.left
            horizontalCenter: root.center ? parent.horizontalCenter : undefined
            leftMargin: Theme.s3
        }
        spacing: Theme.s2

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            font.family: Theme.fontIcon
            font.pixelSize: root.iconSize
            color: root.glyphColor
        }

        Column {
            visible: root.text !== "" || root.subtext !== ""       // icon-only buttons: no empty column, no stray gap
            anchors.verticalCenter: parent.verticalCenter
            // centred: as wide as the text needs (capped to the button); otherwise the whole free width,
            // so long names elide instead of overflowing
            width: root.center ? Math.min(root.maxTextW, Math.max(titleText.implicitWidth, subText.implicitWidth))
                               : root.maxTextW
            spacing: 1
            Text {
                id: titleText
                visible: root.text !== ""
                width: parent.width
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: root.center ? Text.AlignHCenter : Text.AlignLeft
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsBase
                font.weight: Font.Medium
                color: root.fg
            }
            Text {
                id: subText
                visible: root.subtext !== ""
                width: parent.width
                text: root.subtext
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: root.center ? Text.AlignHCenter : Text.AlignLeft
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSmall
                color: root.fg2
            }
        }
    }

    // ------------------------------------------------------------ stacked layout (toggle tiles)
    Column {
        visible: root.stacked
        anchors {
            left: parent.left; leftMargin: Theme.s3
            right: parent.right; rightMargin: Theme.s2
            verticalCenter: parent.verticalCenter
        }
        spacing: 3
        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontIcon
            font.pixelSize: root.iconSize + 2
            color: root.glyphColor
        }
        Text {
            width: parent.width
            text: root.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall + 1
            font.weight: Font.Medium
            color: root.fg
        }
        Text {
            visible: root.subtext !== ""
            width: parent.width
            text: root.subtext
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            color: root.fg2
        }
    }

    Text {
        id: trailingText
        visible: root.trailing !== "" && !root.stacked
        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        text: root.trailing
        textFormat: Text.PlainText
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsSmall
        color: root.fg2
    }

    // keyboard focus ring (Tab only: a mouse click does not give the item focus)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.teal
        visible: root.activeFocus
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
