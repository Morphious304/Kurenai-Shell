import QtQuick

// A row of choice buttons (one is selected). model: [{ value, label }] or plain strings.
Flow {
    id: root

    property var model: []
    property var current
    property int itemWidth: 96
    signal picked(var value)

    spacing: Theme.s1 + 2

    Repeater {
        model: root.model
        Btn {
            required property var modelData
            readonly property var v: typeof modelData === "object" ? modelData.value : modelData
            width: root.itemWidth
            implicitHeight: 30
            center: true
            text: typeof modelData === "object" ? modelData.label : String(modelData)
            checked: root.current === v
            onClicked: root.picked(v)
        }
    }
}
