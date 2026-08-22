// The calendar menu.
//
// Hangs off the clock pill at the right end of the bar — the last StatusPill in
// Bar.qml, the one reading `dd.MM. HH:mm` — and answers the thing that reading
// cannot: which weekday the 24th is, and how far away it is. All of the shape,
// placement and reveal are Chrome.qml's; as with BluetoothFlyout.qml this file
// is only the three declarations that menu asks for — how big the contents are,
// how big they can get, and what they are.
//
// ── Why the size never changes ──────────────────────────────────────────
// Unlike the Bluetooth menu, whose contents grow and shrink with the adapter,
// this one is the same size in every state: seven columns, always six week rows,
// whatever month is showing. That is a decision rather than a coincidence — see
// `weeks` — and it makes both of Chrome's size pairs the same numbers, and makes
// the `pillRight` anchoring that BluetoothFlyout goes to such trouble over
// unnecessary here. Nothing in this menu ever moves out from under the pointer,
// because the menu never resizes.
//
// ── German, and said so out loud ────────────────────────────────────────
// The week starts on Monday and the names are German, matching the `dd.MM.`
// the pill above is already set in. Both are written out below rather than
// asked of a locale, because this machine has no single locale to ask:
// ../../modules/common.nix sets `i18n.defaultLocale = "en_US.UTF-8"` and then
// overrides LC_TIME to de_DE, so which of the two Qt's system locale reflects is
// a detail of how Qt composes the LC_* categories, and the answer would decide
// whether this menu comes up in German or English. The bar next door settled the
// same question the same way, by writing its format string out.
//
// ── The ground ──────────────────────────────────────────────────────────
// Everything here sits on the menu's accent-coloured host, so it is all drawn
// inverted: Theme.background is the ink and Theme.primary is the paper. Which
// means today cannot be marked in the accent the way the bar marks things —
// the whole grid is already that colour — so today is the cell that goes *solid*,
// exactly as a connected row does in DeviceRow.qml. It is drawn as a stadium
// rather than a rounded box on purpose: that is the shape of the clock pill this
// menu hangs from, so the marked day and the reading it belongs to are visibly
// the same object.

import Quickshell
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "clock"

    // ── The current date ────────────────────────────────────────────────
    // Hours rather than Minutes, which is what the bar's clock runs at. The only
    // thing this menu reads off the clock is which day it is, and that changes at
    // midnight — so a minute-precision clock would wake the shell sixty times as
    // often to recompute a value that is identical fifty-nine of those times.
    // Hours is the coarsest precision Quickshell offers and it still ticks on
    // every hour boundary, midnight among them, so the marker moves the moment
    // the day does.
    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property date today: clock.date

    // ── Which month is on screen ────────────────────────────────────────
    // Kept as a normalised year/month pair rather than a Date, so that every
    // binding below has two plain integers to compare against and there is only
    // one place — `showMonth` — where December has to know that it is followed by
    // January.
    property int viewYear
    property int viewMonth

    readonly property bool viewingToday:
        viewYear === today.getFullYear() && viewMonth === today.getMonth()

    Component.onCompleted: showToday()

    // Back to the current month whenever this page becomes the shown one,
    // rather than remembering where paging left off. A calendar opened from a
    // clock is being asked about now; three weeks into the future is a place
    // you went on purpose, and once, and it is not where the next question
    // starts.
    //
    // On the way *in* rather than on the way out, because the page is still
    // faded out at that point (see MenuPage's crossfade), so the heading
    // changing back is never seen. Resetting on the way out would play the
    // same change over the fade the page spends leaving, in full view.
    onActiveChanged: if (active) showToday()

    function showToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    // Paged through a Date rather than by adding to `viewMonth` directly, which
    // is what keeps the pair normalised: month 12 and month -1 are both legal
    // arguments to the Date constructor and both come back out as the right month
    // of the adjacent year.
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

    // ── Where the month starts in the grid ──────────────────────────────
    // How many cells of the previous month come before the 1st.
    //
    // `getDay()` is Sunday-based — Sunday 0, Monday 1, Saturday 6 — and these
    // columns are Monday-first, so the two disagree by one and wrap differently.
    // Adding 6 before the modulo is that rotation: Monday's 1 becomes 0, and
    // Sunday's 0 becomes 6 instead of -1. Getting this wrong does not fail, it
    // silently draws the whole month one column out.
    readonly property int leading:
        (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property int columns: 7

    // Six rows, always, even for the months that fit in five and for the
    // February that fits in four. Sizing the grid to the month means the menu
    // changes height under the pointer as you page through it — and paging is a
    // repeated action, so the box would be resizing between one click and the
    // next, on the very control being clicked. An empty row some months is the
    // cheaper of the two.
    //
    // Six is also the ceiling: a 31-day month starting on a Sunday needs 6 rows
    // and nothing needs 7.
    readonly property int weeks: 6

    // Wide enough that the heading row — the month name and its three chips —
    // fits inside the width the grid already dictates, so the grid is what sets
    // the menu's width and the heading never has to widen it.
    readonly property int cellWidth: 34
    readonly property int cellHeight: 24

    readonly property int headerHeight: 22   // a Chip's own height
    readonly property int weekdayHeight: 18
    readonly property int gap: Tokens.spacing.small

    // What Chrome needs. The worst case is the only case: the contents are a
    // fixed grid — there is no state this menu can be in that is a different size
    // — so the surface is sized to exactly what it will always be asked to hold.
    contentWidth: columns * cellWidth
    contentHeight: headerHeight + gap + weekdayHeight + weeks * cellHeight

    maxContentHeight: contentHeight

    // Two characters each, which is what makes the seven columns line up under a
    // grid whose cells are all one width. The locale's own abbreviations would be
    // the obvious source and are not usable for that reason: CLDR's German
    // formats vary between "Mo" and "Mo." depending on which of the abbreviated
    // and stand-alone forms you ask for, and a trailing period on some headers
    // and not others is visible in a monospace grid.
    readonly property var weekdayNames: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    readonly property var monthNames: [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"
    ]

    ColumnLayout {
        anchors.fill: parent

        // Zero, and the one gap that is wanted is a margin below. The weekday
        // letters are the grid's column headings rather than a band of their own,
        // so they belong against the days they label and apart from the heading
        // above them.
        spacing: 0

        // ── The heading ─────────────────────────────────────────────────
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

            // ── The three controls ──────────────────────────────────────
            // At the right end, which is the end nearest the pill: the clock is
            // the last thing on the bar and the menu is flush to the screen edge
            // under it, so the pointer arrives here and has the shortest distance
            // to travel.
            //
            // Chip's signal is `toggled` because its first use was a pair of
            // switches. These three are momentary presses, so none of them sets
            // `active` — a lit chip means the desktop is in a state, and "go to
            // next month" is not a state to be in.

            // Only live when there is somewhere to go back to. `available` rather
            // than hiding it, unlike the scan chip in BluetoothFlyout.qml: that
            // menu collapses around its one remaining button, this one is a fixed
            // grid, so a chip that vanished would leave a hole in a row that is
            // not going to close up anyway.
            Chip {
                Layout.rightMargin: Tokens.spacing.small
                glyph: String.fromCodePoint(0xf00f6)  // md-calendar_today
                available: !menu.viewingToday
                onToggled: menu.showToday()
            }

            // The two arrows are adjacent, and the jump back to today is set
            // apart from them, so that paging back and forth — which is the
            // repeated gesture here — never drags the pointer across a third
            // button that would undo it.
            Chip {
                glyph: String.fromCodePoint(0xf0141)  // md-chevron_left
                onToggled: menu.showMonth(-1)
            }

            Chip {
                glyph: String.fromCodePoint(0xf0142)  // md-chevron_right
                onToggled: menu.showMonth(1)
            }
        }

        // ── The column headings ─────────────────────────────────────────
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
                    // Secondary ink: these are read once on the way in and then
                    // never again, while the numbers under them are read every
                    // time the menu is opened.
                    color: Qt.alpha(Theme.background, 0.6)
                    font.family: Theme.fontFamily
                    font.pixelSize: Tokens.fontSize.small
                }
            }
        }

        // ── The month ───────────────────────────────────────────────────
        // A plain Grid rather than a GridLayout: every cell is the same fixed
        // size, so there is nothing for a layout to negotiate, and 42 sets of
        // attached Layout properties would be paid for on every reflow.
        //
        // No entry animation on the cells, deliberately, though DeviceRow.qml has
        // one and it is what gives that menu its arrival. Six rows of seven at
        // that stagger is well over a second of grid assembling itself, replayed
        // on every press of the arrows — which would make the menu slowest to
        // read exactly while it is being paged through fastest.
        Grid {
            columns: menu.columns

            Repeater {
                model: menu.columns * menu.weeks

                Item {
                    id: cell

                    required property int index

                    // Day-of-month arithmetic outside 1..31 is legal and
                    // normalising, so the leading cells count backwards into the
                    // previous month and the trailing ones run on into the next
                    // without either case being special.
                    readonly property date day: new Date(
                        menu.viewYear, menu.viewMonth, 1 - menu.leading + index)

                    readonly property bool inMonth:
                        day.getMonth() === menu.viewMonth
                    readonly property bool isToday: menu.isSameDay(day, menu.today)

                    width: menu.cellWidth
                    height: menu.cellHeight

                    // Today, filled. `full` gives the stadium whatever the height
                    // is, the same way the bar's pills get theirs.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.extraSmall
                        radius: Tokens.rounding.full
                        color: cell.isToday ? Theme.background : "transparent"

                        // Which matters on exactly two occasions: midnight, and
                        // paging away from the current month. The second is the
                        // one that is watched, and without this the marker would
                        // blink out of one grid and into another in a single
                        // frame while everything else stayed put.
                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        // Three levels, not two: the accent showing through the
                        // filled marker for today, full ink for this month, and
                        // the spill from the neighbouring months dimmer than the
                        // column headings are — they are context for where the
                        // weeks break, not dates anyone is here to read.
                        color: cell.isToday ? Theme.primary
                             : cell.inMonth ? Theme.background
                             : Qt.alpha(Theme.background, 0.35)
                        font.family: Theme.fontFamily
                        font.pixelSize: Tokens.fontSize.small

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    // No hover state and no tap handler. There is nothing behind
                    // a day — no events, no agenda — and a cell that lit up under
                    // the pointer would be, in StatusPill.qml's words, a promise
                    // the bar cannot keep.
                }
            }
        }
    }
}
