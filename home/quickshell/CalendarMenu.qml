// Monday-first German calendar with the selected day's CalDAV agenda beside it.

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
    property date selected: today

    readonly property bool viewingToday:
        viewYear === today.getFullYear() && viewMonth === today.getMonth()

    Component.onCompleted: showToday()

    // Return to the current day each time the calendar opens.
    onActiveChanged: {
        if (!active) return;
        showToday();
        Agenda.refreshIfStale();
    }

    function showToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selected = today;
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

    function timeOf(day) {
        return Qt.formatTime(day, "HH:mm");
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

    readonly property int gridWidth: columns * cellWidth
    readonly property int gridHeight:
        headerHeight + gap + weekdayHeight + weeks * cellHeight

    readonly property int agendaWidth: 260
    readonly property int rowHeight: 34
    readonly property int rowGap: Tokens.spacing.extraSmall
    readonly property int maxRows: 4

    readonly property var dayEvents: Agenda.eventsOn(selected)
    readonly property var shownEvents: dayEvents.slice(0, maxRows)
    readonly property int hiddenEvents: dayEvents.length - shownEvents.length

    contentWidth: gridWidth + Tokens.spacing.large + agendaWidth
    contentHeight: gridHeight

    maxContentHeight: contentHeight

    readonly property var weekdayNames: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    readonly property var monthNames: [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"
    ]

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.large

        ColumnLayout {
            Layout.preferredWidth: menu.gridWidth
            Layout.fillHeight: true
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
                    available: !menu.viewingToday || !menu.isSameDay(menu.selected, menu.today)
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
                        readonly property bool isSelected: menu.isSameDay(day, menu.selected)
                        readonly property bool busy: Agenda.eventsOn(day).length > 0

                        width: menu.cellWidth
                        height: menu.cellHeight

                        // Square marks: the grid reads as a table, not a row of pills.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Tokens.spacing.extraSmall
                            radius: 0
                            color: cell.isToday ? "transparent"
                                 : cell.isSelected ? Qt.alpha(Theme.background, 0.24)
                                 : cellHover.hovered ? Qt.alpha(Theme.background, 0.12)
                                 : "transparent"
                            border.width: cell.isSelected && !cell.isToday ? 1 : 0
                            border.color: Qt.alpha(Theme.background, 0.6)

                            Behavior on color { CAnim { motion: Motion.fastEffect } }
                        }

                        Frame {
                            anchors.fill: parent
                            anchors.margins: Tokens.spacing.extraSmall
                            shown: cell.isToday
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

                        // A dot marks days that have events. Today is filled and its
                        // agenda opens by default, so it needs none.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            width: 3
                            height: 3
                            visible: cell.busy && !cell.isToday
                            color: Qt.alpha(Theme.background, cell.inMonth ? 1 : 0.35)
                        }

                        HoverHandler {
                            id: cellHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler { onTapped: menu.selected = cell.day }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: menu.agendaWidth
            Layout.fillHeight: true
            spacing: menu.gap

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.headerHeight
                spacing: Tokens.spacing.small

                Text {
                    Layout.fillWidth: true
                    text: menu.weekdayNames[(menu.selected.getDay() + 6) % 7] + " "
                        + Qt.formatDate(menu.selected, "dd.MM.")
                        + (menu.dayEvents.length > 0
                            ? "  ·  " + menu.dayEvents.length : "")
                    color: Theme.background
                    font.family: Theme.fontFamily
                    font.pixelSize: Tokens.fontSize.normal
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Chip {
                    glyph: String.fromCodePoint(
                        Agenda.failed ? 0xf04e7    // md-sync-alert
                                      : 0xf04e6)   // md-sync
                    available: !Agenda.syncing
                    working: Agenda.syncing
                    onToggled: Agenda.refresh()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: menu.rowGap

                Repeater {
                    model: menu.shownEvents

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property string link: modelData.meeting || modelData.url || ""
                        readonly property bool joinable: modelData.meeting !== null
                        readonly property bool past: modelData.end <= menu.today

                        Layout.fillWidth: true
                        Layout.preferredHeight: menu.rowHeight

                        opacity: 0
                        Component.onCompleted: entry.start()
                        Anim {
                            id: entry
                            target: row; property: "opacity"
                            to: 1; motion: Motion.effect
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: rowHover.hovered && row.link !== ""
                                ? Qt.alpha(Theme.background, 0.10) : "transparent"

                            Behavior on color { CAnim { motion: Motion.fastEffect } }
                        }

                        HoverHandler {
                            id: rowHover
                            cursorShape: row.link !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        }
                        TapHandler { onTapped: Agenda.open(row.link) }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing.small
                            anchors.rightMargin: Tokens.spacing.extraSmall
                            spacing: Tokens.spacing.small

                            ColumnLayout {
                                Layout.preferredWidth: 40
                                spacing: 0

                                Text {
                                    text: row.modelData.allDay ? "all day" : menu.timeOf(row.modelData.start)
                                    color: Qt.alpha(Theme.background, row.past ? 0.5 : 1)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Tokens.fontSize.small
                                }
                                Text {
                                    visible: !row.modelData.allDay
                                    text: menu.timeOf(row.modelData.end)
                                    color: Qt.alpha(Theme.background, 0.5)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Tokens.fontSize.small
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.summary
                                    elide: Text.ElideRight
                                    color: Qt.alpha(Theme.background, row.past ? 0.5 : 1)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Tokens.fontSize.small
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.location
                                    elide: Text.ElideRight
                                    color: Qt.alpha(Theme.background, 0.5)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Tokens.fontSize.small
                                }
                            }

                            Chip {
                                visible: row.link !== ""
                                glyph: String.fromCodePoint(
                                    row.joinable ? 0xf0567    // md-video
                                                 : 0xf03cc)   // md-open-in-new
                                active: row.joinable && !row.past
                                onToggled: Agenda.open(row.link)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.rowHeight
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Tokens.spacing.small
                    visible: menu.dayEvents.length === 0
                    color: Qt.alpha(Theme.background, 0.7)
                    font.family: Theme.fontFamily
                    font.pixelSize: Tokens.fontSize.small
                    text: Agenda.failed && Agenda.events.length === 0
                        ? "sync failed" : "no events"
                }

                Text {
                    Layout.fillWidth: true
                    visible: menu.hiddenEvents > 0
                    leftPadding: Tokens.spacing.small
                    color: Qt.alpha(Theme.background, 0.6)
                    font.family: Theme.fontFamily
                    font.pixelSize: Tokens.fontSize.small
                    text: "+" + menu.hiddenEvents + " more"
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
