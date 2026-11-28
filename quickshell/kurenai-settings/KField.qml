import QtQuick

// A one-line text box. `value` is what the setting really holds; typing changes only the box, and `commit(text)` is sent
// when you press Enter or leave the box with a different text (so nothing is saved on every keystroke).
Rectangle {
    id: root

    property string value: ""
    property string placeholder: ""
    property bool mono: false
    property bool numeric: false
    property alias text: input.text
    signal commit(string newText)

    implicitWidth: 220
    implicitHeight: 32
    radius: Theme.rMd
    color: Theme.surface
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    onValueChanged: if (!input.activeFocus) input.text = value
    Component.onCompleted: input.text = value

    function focusInput() { input.forceActiveFocus(); input.selectAll(); }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; leftMargin: Theme.s3; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        font.family: root.mono ? Theme.fontMono : Theme.fontUi
        font.pixelSize: Theme.fsBase
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.inkOnAccent
        selectByMouse: true
        clip: true
        activeFocusOnTab: true
        cursorDelegate: Rectangle { width: 2; color: Theme.accent }
        inputMethodHints: root.numeric ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
        onEditingFinished: if (input.text !== root.value) root.commit(input.text)
        Keys.onEscapePressed: { input.text = root.value; input.focus = false; }

        Text {
            visible: input.text === "" && !input.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            font: input.font
            color: Theme.muted
        }
    }
}
