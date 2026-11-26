import QtQuick

// A short scrollable list: grows with its rows up to `maxRows`, then scrolls.
// Put rows (or a Repeater) inside.
Flickable {
    id: root

    property int rows: Config.qsMaxListRows
    property int rowHeight: 34
    default property alias content: col.data

    height: Math.min(col.implicitHeight, rows * rowHeight)
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: root.width
        spacing: 2
    }
}
