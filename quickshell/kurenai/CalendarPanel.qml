import QtQuick
import Quickshell

// Month calendar, fully offline (plain date arithmetic, no calendar service).
// Opened by clicking the clock, or: qs -c kurenai ipc call calendar toggle
//   today       = filled vermilion (and bold)
//   selected    = teal outline on a raised cell (a different day from today)
// Keys: arrows move the selected day, PageUp/PageDown change month, Home jumps to today, Esc closes.
PanelOverlay {
    id: root

    open: UiState.calendarOpen
    place: "top-right"
    docked: Config.popoverDocked && !Compositor.fullscreen
    layerName: "kurenai-calendar"
    onDismissed: UiState.calendarOpen = false

    // ---------------------------------------------------------------- date state
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property var selected: new Date()

    readonly property var today: clock.date            // follows midnight automatically
    readonly property int firstDow: (Config.firstDayOfWeek >= 0 ? Config.firstDayOfWeek : Qt.locale().firstDayOfWeek) % 7
    readonly property var monthKanji: ["\u4E00\u6708", "\u4E8C\u6708", "\u4E09\u6708", "\u56DB\u6708", "\u4E94\u6708", "\u516D\u6708",
                                       "\u4E03\u6708", "\u516B\u6708", "\u4E5D\u6708", "\u5341\u6708", "\u5341\u4E00\u6708", "\u5341\u4E8C\u6708"]

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function dayStart(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }

    function goToday() {
        const t = new Date();
        selected = t;
        viewYear = t.getFullYear();
        viewMonth = t.getMonth();
    }
    function moveSelected(days) {
        const d = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + days);
        selected = d;
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }
    function moveMonth(delta) {
        const first = new Date(viewYear, viewMonth + delta, 1);
        viewYear = first.getFullYear();
        viewMonth = first.getMonth();
        // keep the selected day number where possible (31 Jan -> 28/29 Feb)
        const last = new Date(viewYear, viewMonth + 1, 0).getDate();
        selected = new Date(viewYear, viewMonth, Math.min(selected.getDate(), last));
    }
    function selectDate(d) {
        selected = d;
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    onOpenChanged: {
        if (open) {
            goToday();
            Qt.callLater(() => keyCatcher.forceActiveFocus());
        }
    }

    // 6 weeks x 7 days, starting on the locale's first weekday; days outside the month are shown dimmed
    readonly property var cells: {
        const first = new Date(viewYear, viewMonth, 1);
        const offset = (first.getDay() - firstDow + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(viewYear, viewMonth, 1 - offset + i));
        return out;
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dow = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dow);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }
    function dayOfYear(d) {
        return Math.round((dayStart(d) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }
    readonly property string relative: {
        const diff = Math.round((dayStart(selected) - dayStart(today)) / 86400000);
        if (diff === 0) return "Today";
        if (diff === 1) return "Tomorrow";
        if (diff === -1) return "Yesterday";
        return diff > 0 ? "In " + diff + " days" : (-diff) + " days ago";
    }

    PanelFrame {
        id: frame
        docked: root.docked
        bodyWidth: 308
        bodyHeight: col.implicitHeight + Theme.s3 * 2

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Column {
            id: col
            x: Theme.s3
            y: Theme.s3
            width: parent.width - Theme.s3 * 2
            spacing: Theme.s2

            // ---------------------------------------------------------------- header
            Item {
                width: parent.width
                height: 40

                Column {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Row {
                        spacing: Theme.s2
                        height: 28
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.locale().monthName(root.viewMonth, Locale.LongFormat)
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase + 5
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.viewYear
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsBase
                            color: Theme.muted
                        }
                        Text {                       // decorative month kanji (a Japanese font is optional)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.monthKanji[root.viewMonth]
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fsBase
                            color: Theme.accentText
                        }
                    }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.s1
                    Btn { width: 28; height: 28; flat: true; center: true; icon: Theme.icons.chevL; iconSize: 11; onClicked: root.moveMonth(-1) }
                    Btn { width: 56; height: 28; flat: true; center: true; text: "Today"; onClicked: root.goToday() }
                    Btn { width: 28; height: 28; flat: true; center: true; icon: Theme.icons.chevR; iconSize: 11; onClicked: root.moveMonth(1) }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------------------------------------------------------- weekday names
            Row {
                width: parent.width
                Repeater {
                    model: 7
                    delegate: Text {
                        required property int index
                        width: col.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.ShortFormat)
                        elide: Text.ElideRight
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSmall
                        font.letterSpacing: 0.5
                        color: Theme.muted
                    }
                }
            }

            // ---------------------------------------------------------------- the month grid
            FocusScope {
                id: keyCatcher
                width: parent.width
                height: grid.height
                activeFocusOnTab: true

                Keys.onLeftPressed: root.moveSelected(-1)
                Keys.onRightPressed: root.moveSelected(1)
                Keys.onUpPressed: root.moveSelected(-7)
                Keys.onDownPressed: root.moveSelected(7)
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_PageUp) { root.moveMonth(-1); e.accepted = true; }
                    else if (e.key === Qt.Key_PageDown) { root.moveMonth(1); e.accepted = true; }
                    else if (e.key === Qt.Key_Home) { root.goToday(); e.accepted = true; }
                }

                Grid {
                    id: grid
                    columns: 7
                    width: parent.width
                    Repeater {
                        model: root.cells
                        delegate: Rectangle {
                            id: cell
                            required property var modelData
                            readonly property bool inMonth: modelData.getMonth() === root.viewMonth
                            readonly property bool isToday: root.sameDay(modelData, root.today)
                            readonly property bool isSelected: root.sameDay(modelData, root.selected)

                            width: grid.width / 7
                            height: 34
                            radius: Theme.rMd
                            // today: solid vermilion; selected: raised + teal outline; both can apply at once
                            color: isToday ? Theme.accent : isSelected ? Theme.raised : (cellArea.containsMouse ? Theme.surface : "transparent")
                            border.width: isSelected ? 2 : 0
                            border.color: Theme.teal

                            Text {
                                anchors.centerIn: parent
                                text: cell.modelData.getDate()
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsBase
                                font.weight: cell.isToday ? Font.Bold : Font.Normal
                                color: cell.isToday ? Theme.inkOnAccent : cell.inMonth ? Theme.text : Theme.muted
                                opacity: cell.inMonth || cell.isToday ? 1 : 0.7
                            }
                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.selectDate(cell.modelData); keyCatcher.forceActiveFocus(); }
                            }
                        }
                    }
                }

                // mouse wheel over the grid changes month
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: w => root.moveMonth(w.angleDelta.y > 0 ? -1 : 1)
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // ---------------------------------------------------------------- selected day
            Column {
                width: parent.width
                spacing: 2
                bottomPadding: Theme.s1
                Text {
                    width: parent.width
                    text: Qt.formatDate(root.selected, "dddd, d MMMM yyyy")
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase + 1
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    width: parent.width
                    text: root.relative + "  \u00B7  week " + root.isoWeek(root.selected) + "  \u00B7  day " + root.dayOfYear(root.selected)
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSmall
                    color: root.sameDay(root.selected, root.today) ? Theme.accentText : Theme.muted
                }
            }
        }
    }
}
