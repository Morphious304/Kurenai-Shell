import QtQuick

// Vermilion seal (hanko) with the character for "crimson", plus an English wordmark.
// The kanji is decorative; the functional label is the English text.
Item {
    id: root
    property bool showWordmark: true

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.itemHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.s2

        Rectangle {
            width: 22
            height: 22
            radius: Theme.rSm
            color: area.containsMouse ? Theme.accentText : Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.durFast } }

            Text {
                anchors.centerIn: parent
                text: "\u7D05"          // kanji for "crimson"
                font.family: Theme.fontDisplay
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.inkOnAccent
            }
        }

        Text {
            visible: root.showWordmark
            anchors.verticalCenter: parent.verticalCenter
            text: "KURENAI"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSmall
            font.weight: Font.DemiBold
            font.letterSpacing: 2
            color: Theme.text2
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: UiState.toggleLauncher()   // launcher arrives in phase 3
    }
}
