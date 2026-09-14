// Monday-first German calendar, matching the bar's date format.

import Quickshell
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "clock"

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property date today: clock.date

    property int viewYear
    property int viewMonth

    readonly property bool viewingToday:
        viewYear === today.getFullYear() && viewMonth === today.getMonth()

    Component.onCompleted: showToday()

    // Return to the current month each time the calendar opens.
    onActiveChanged: if (active) showToday()

    function showToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    // Date normalises month overflow across year boundaries.
    function showMonth(delta) {
        const moved = new Date(viewYear, viewMonth + delta, 1);
        viewYear = moved.getFullYear();
        viewMonth = moved.getMonth();
    }

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    // Rotate the Sunday-based JS weekday to a Monday-first grid.
    readonly property int leading:
        (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7

    readonly property int columns: 7

    // Keep six rows so navigation controls never move between months.
    readonly property int weeks: 6

    readonly property int cellWidth: 34
    readonly property int cellHeight: 24

    readonly property int headerHeight: 22   // a Chip's own height
    readonly property int weekdayHeight: 18
    readonly property int gap: Tokens.spacing.small

    contentWidth: columns * cellWidth
    contentHeight: headerHeight + gap + weekdayHeight + weeks * cellHeight

    maxContentHeight: contentHeight

    readonly property var weekdayNames: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    readonly property var monthNames: [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"
    ]

    ColumnLayout {
        anchors.fill: parent

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight
            spacing: Tokens.spacing.extraSmall

            Text {
                Layout.fillWidth: true
                text: menu.monthNames[menu.viewMonth] + " " + menu.viewYear
                color: Theme.background
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.normal
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Chip {
                Layout.rightMargin: Tokens.spacing.small
                glyph: String.fromCodePoint(0xf00f6)  // md-calendar_today
                available: !menu.viewingToday
                onToggled: menu.showToday()
            }

            Chip {
                glyph: String.fromCodePoint(0xf0141)  // md-chevron_left
                onToggled: menu.showMonth(-1)
            }

            Chip {
                glyph: String.fromCodePoint(0xf0142)  // md-chevron_right
                onToggled: menu.showMonth(1)
            }
        }

        Row {
            Layout.topMargin: menu.gap
            Layout.preferredHeight: menu.weekdayHeight

            Repeater {
                model: menu.weekdayNames

                Text {
                    required property string modelData

                    width: menu.cellWidth
                    height: menu.weekdayHeight
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Qt.alpha(Theme.background, 0.6)
                    font.family: Theme.fontFamily
                    font.pixelSize: Tokens.fontSize.small
                }
            }
        }

        Grid {
            columns: menu.columns

            Repeater {
                model: menu.columns * menu.weeks

                Item {
                    id: cell

                    required property int index

                    readonly property date day: new Date(
                        menu.viewYear, menu.viewMonth, 1 - menu.leading + index)

                    readonly property bool inMonth:
                        day.getMonth() === menu.viewMonth
                    readonly property bool isToday: menu.isSameDay(day, menu.today)

                    width: menu.cellWidth
                    height: menu.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.extraSmall
                        radius: Tokens.rounding.full
                        color: cell.isToday ? Theme.background : "transparent"

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        color: cell.isToday ? Theme.primary
                             : cell.inMonth ? Theme.background
                             : Qt.alpha(Theme.background, 0.35)
                        font.family: Theme.fontFamily
                        font.pixelSize: Tokens.fontSize.small

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                }
            }
        }
    }
}
