import QtQuick

// A button for something you cannot take back: the first click arms it ("Click again to confirm", 4 seconds),
// the second click does it. Nothing destructive ever runs from a single click.
Btn {
    id: root

    property string label: ""
    property string confirmText: "Click again to confirm"
    property bool armed: false
    signal confirmed()

    implicitWidth: 190
    text: armed ? confirmText : label
    center: true
    checked: armed

    onClicked: {
        if (armed) { armed = false; disarm.stop(); confirmed(); }
        else { armed = true; disarm.restart(); }
    }
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = false }
}
