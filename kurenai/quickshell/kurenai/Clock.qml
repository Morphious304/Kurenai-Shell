import QtQuick
import Quickshell

// Updates once per minute via SystemClock (no timers, no external commands).
// Click = calendar panel.
BarItem {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    label: Qt.formatDateTime(clock.date, Theme.timeFormat)
    labelFamily: Theme.fontMono
    labelColor: Theme.text
    active: UiState.calendarOpen
    onClicked: UiState.toggleCalendar()
}
