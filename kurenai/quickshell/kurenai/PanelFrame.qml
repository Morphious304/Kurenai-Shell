import QtQuick

// A panel body that is either a floating card (Surface) or hangs from the bar (DockShape),
// same logic the launcher uses. Give it bodyWidth / bodyHeight and put content inside; the
// content coordinate system is the BODY (the docked fillets sit outside it, left and right).
Item {
    id: root

    property bool docked: false
    property real bodyWidth: Theme.qsWidth
    property real bodyHeight: 200
    property int fillet: Theme.rLg
    default property alias content: body.data

    width: bodyWidth + (docked ? 2 * fillet : 0)
    height: bodyHeight

    Surface { visible: !root.docked; anchors.fill: parent }
    DockShape { visible: root.docked; anchors.fill: parent; fillet: root.fillet }

    // clicks on the panel must not reach "click outside = close"
    MouseArea {
        anchors.fill: body
        acceptedButtons: Qt.AllButtons
        onClicked: m => m.accepted = true
    }

    Item {
        id: body
        x: root.docked ? root.fillet : 0
        width: root.bodyWidth
        height: root.bodyHeight
    }
}
