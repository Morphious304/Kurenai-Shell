import QtQuick

// Every setting of one kurenai-conf group, as rows.
Card {
    id: root
    property string group: ""

    Repeater {
        model: Store.rowsOf(root.group)
        SRow {
            required property var modelData
            meta: modelData
        }
    }
}
