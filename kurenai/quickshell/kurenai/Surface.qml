import QtQuick

// The KURENAI panel surface: 95% charcoal, hairline bone border, rounded.
// Clicks on the surface are swallowed so PanelOverlay's click-outside-to-close does not fire.
// `accent` draws a thin vermilion rule along the top edge: the one ornamental detail.
Rectangle {
    id: root

    property bool accent: true
    property int padding: Theme.s3

    color: Theme.panelBg
    radius: Theme.rLg
    border.width: 1
    border.color: Theme.panelBorder

    // vermilion hairline, inset so it does not fight the rounded corners
    Rectangle {
        visible: root.accent
        anchors { top: parent.top; topMargin: 0; horizontalCenter: parent.horizontalCenter }
        width: parent.width - Theme.rLg * 2
        height: 2
        radius: 1
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: m => m.accepted = true
        z: -1
    }
}
