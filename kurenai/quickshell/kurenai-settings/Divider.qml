import QtQuick

// Hairline separator. Item height matches Theme.itemHeight so it centres inside Rows.
Item {
    implicitWidth: 1
    implicitHeight: Theme.itemHeight

    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: 14
        color: Theme.border
    }
}
