import QtQuick

// One setting from `kurenai-conf schema`: the right control for its type, "changed" + Reset, and the exact command.
Line {
    id: row

    property var meta: ({ key: "", type: "string", label: "", help: "" })
    readonly property string key: meta.key
    readonly property var value: Store.val(key)

    title: meta.label
    sub: meta.help
    command: Cli.show("kurenai-conf", Store.setArgs(key, value === undefined ? "" : value))
    changed: Store.isChanged(key)
    defaultText: Array.isArray(meta.default) ? meta.default.join(", ") : String(meta.default)
    highlighted: App.focusKey === key && key !== ""
    wide: meta.type === "list" || meta.type === "enum"

    onResetClicked: Store.reset(key)
    onHighlightedChanged: if (highlighted) Qt.callLater(() => App.scrollRequest(row))
    Component.onCompleted: if (highlighted) Qt.callLater(() => App.scrollRequest(row))

    Loader {
        width: row.wide ? (parent ? parent.width : 0) : implicitWidth
        sourceComponent: row.meta.type === "bool" ? cBool
                       : (row.meta.type === "int" || row.meta.type === "real") ? cNum
                       : row.meta.type === "enum" ? cEnum
                       : row.meta.type === "list" ? cList
                       : cStr
    }

    Component {
        id: cBool
        KToggle {
            checked: row.value === true
            onToggled: Store.set(row.key, !checked)
        }
    }

    Component {
        id: cStr
        KField {
            width: 250
            mono: false
            value: row.value === undefined ? "" : String(row.value)
            onCommit: t => Store.set(row.key, t)
        }
    }

    Component {
        id: cEnum
        Seg {
            width: parent ? parent.width : 400
            itemWidth: 88
            model: row.meta.choices || []
            current: row.value
            onPicked: v => Store.set(row.key, v)
        }
    }

    Component {
        id: cNum
        Row {
            id: numRow
            spacing: Theme.s3
            readonly property bool isInt: row.meta.type === "int"
            readonly property real lo: row.meta.min === undefined ? 0 : Number(row.meta.min)
            readonly property real hi: row.meta.max === undefined ? 100 : Number(row.meta.max)
            property real draft: 0
            readonly property real shown: settle.running ? draft : Number(row.value)
            function fmt(v) { return isInt ? String(Math.round(v)) : String(Math.round(v * 100) / 100); }
            function clamp(v) { v = Math.max(lo, Math.min(hi, v)); return isInt ? Math.round(v) : Math.round(v * 100) / 100; }
            function propose(v) { draft = clamp(v); settle.restart(); }
            Timer { id: settle; interval: 350; onTriggered: Store.set(row.key, numRow.draft) }

            KSlider {
                width: 170
                anchors.verticalCenter: parent.verticalCenter
                from: numRow.lo
                to: numRow.hi
                step: numRow.isInt ? Math.max(1, Math.round((numRow.hi - numRow.lo) / 100)) : (numRow.hi - numRow.lo) / 100
                value: numRow.shown
                onMoved: v => numRow.propose(v)
            }
            KField {
                width: 76
                anchors.verticalCenter: parent.verticalCenter
                mono: true
                numeric: true
                value: numRow.fmt(numRow.shown)
                onCommit: t => {
                    const n = Number(String(t).replace(",", "."));
                    if (isNaN(n)) { text = numRow.fmt(numRow.shown); return; }
                    numRow.draft = numRow.clamp(n);
                    settle.stop();
                    Store.set(row.key, numRow.draft);
                }
            }
        }
    }

    Component {
        id: cList
        Flow {
            id: chips
            width: parent ? parent.width : 400
            spacing: Theme.s1 + 2
            readonly property var items: Array.isArray(row.value) ? row.value : []
            function write(list) { Store.set(row.key, list); }

            Repeater {
                model: chips.items
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    height: 30
                    width: chipRow.implicitWidth + Theme.s3 + 4
                    radius: Theme.rMd
                    color: Theme.raised
                    border.width: 1
                    border.color: Theme.border
                    Row {
                        id: chipRow
                        x: Theme.s3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.s1
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData
                            textFormat: Text.PlainText
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsSmall + 1
                            color: Theme.text
                        }
                        Btn {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            implicitHeight: 26
                            flat: true
                            center: true
                            icon: Theme.icons.close
                            iconSize: 10
                            onClicked: chips.write(chips.items.filter((x, i) => i !== chip.index))
                        }
                    }
                }
            }
            KField {
                id: adder
                width: 230
                mono: true
                placeholder: "add one, press Enter"
                onCommit: t => {
                    const v = String(t).replace(/,/g, " ").trim();
                    text = "";
                    if (v === "" || chips.items.indexOf(v) >= 0) return;
                    chips.write(chips.items.concat([v]));
                }
            }
        }
    }
}
