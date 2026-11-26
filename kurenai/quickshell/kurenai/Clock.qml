import QtQuick
import Quickshell

// Updates once per minute via SystemClock (no timers, no external commands).
BarItem {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    label: Qt.formatDateTime(clock.date, Theme.timeFormat)
    labelFamily: Theme.fontMono
    labelColor: Theme.text
}
