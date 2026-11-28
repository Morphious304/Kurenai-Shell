import QtQuick

// Shows what a read-only kurenai-* command prints (status reports and the like), with the command above it and Refresh.
Rectangle {
    id: root

    property string prog: "kurenai-ctl"
    property var args: []
    property string emptyText: "Nothing to show."
    property bool refreshOnWrite: true
    property string text: ""
    property bool loading: false
    property int maxHeight: 260

    function refresh() {
        loading = true;
        Cli.read(prog, args, res => { text = res.text; loading = false; });
    }
    property bool ready: false
    Component.onCompleted: { ready = true; refresh(); }
    onArgsChanged: if (ready) refresh()
    Connections { target: Cli; function onWrote() { if (root.refreshOnWrite) again.restart(); } }
    Timer { id: again; interval: 700; onTriggered: root.refresh() }

    width: parent ? parent.width : 400
    height: head.height + body.height + Theme.s3 * 2 + Theme.s2
    radius: Theme.rMd
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

    Item {
        id: head
        x: Theme.s3; y: Theme.s3
        width: parent.width - Theme.s3 * 2
        height: 26
        Text {
            anchors { left: parent.left; right: refreshBtn.left; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
            text: "$ " + Cli.show(root.prog, root.args)
            elide: Text.ElideRight
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall
            color: Theme.muted
        }
        Btn {
            id: refreshBtn
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 84; height: 26; implicitHeight: 26
            center: true
            text: root.loading ? "..." : "Refresh"
            onClicked: root.refresh()
        }
    }

    Flickable {
        id: body
        x: Theme.s3
        y: head.y + head.height + Theme.s2
        width: parent.width - Theme.s3 * 2
        height: Math.min(root.maxHeight, Math.max(24, contentHeight))
        contentWidth: width
        contentHeight: out.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: out
            width: body.width
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            text: root.text !== "" ? root.text : (root.loading ? "Reading..." : root.emptyText)
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSmall + 1
            color: Theme.text2
            selectionColor: Theme.accent
            selectedTextColor: Theme.inkOnAccent
        }
    }
}
