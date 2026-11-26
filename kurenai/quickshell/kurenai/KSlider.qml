import QtQuick

// Horizontal slider used for volume, microphone and brightness.
//   mouse/touchpad: click or drag the track, scroll wheel nudges
//   keyboard:       Tab to focus, Left/Right = one step, PageUp/PageDown = 4 steps, Home/End
// `value` is owned by the caller; the slider emits moved(v) and the caller writes it to the
// real thing (PipeWire, brightnessctl), so the knob always reflects the real value.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    property color fillColor: Theme.accent
    signal moved(real value)

    implicitHeight: 24
    implicitWidth: 160
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: enabled

    readonly property real span: Math.max(0.0001, to - from)
    // while dragging, follow the pointer instead of the (slightly delayed) real value
    property real dragValue: 0
    readonly property real shown: area.pressed ? dragValue : value
    readonly property real frac: Math.max(0, Math.min(1, (shown - from) / span))

    function clamp(v) { return Math.max(from, Math.min(to, v)); }
    function nudge(delta) { root.moved(clamp(value + delta)); }

    Keys.onLeftPressed: nudge(-step)
    Keys.onDownPressed: nudge(-step)
    Keys.onRightPressed: nudge(step)
    Keys.onUpPressed: nudge(step)
    Keys.onPressed: e => {
        if (e.key === Qt.Key_PageUp) { nudge(step * 4); e.accepted = true; }
        else if (e.key === Qt.Key_PageDown) { nudge(-step * 4); e.accepted = true; }
        else if (e.key === Qt.Key_Home) { root.moved(from); e.accepted = true; }
        else if (e.key === Qt.Key_End) { root.moved(to); e.accepted = true; }
    }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6
        radius: 3
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderStrong

        Rectangle {
            width: Math.max(0, root.frac * (track.width - knob.width) + knob.width / 2)
            height: parent.height
            radius: 3
            color: root.fillColor
        }
    }

    Rectangle {
        id: knob
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: root.frac * (root.width - width)
        color: Theme.text
        border.width: root.activeFocus ? 3 : 0
        border.color: Theme.teal
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        function setFromX(x) {
            const f = Math.max(0, Math.min(1, (x - knob.width / 2) / (root.width - knob.width)));
            root.dragValue = root.from + f * root.span;
            root.moved(root.dragValue);
        }
        onPressed: m => setFromX(m.x)
        onPositionChanged: m => { if (pressed) setFromX(m.x); }
        onWheel: w => root.nudge(w.angleDelta.y > 0 ? root.step : -root.step)
    }
}
