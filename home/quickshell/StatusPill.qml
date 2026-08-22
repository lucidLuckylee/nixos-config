// One readout on the right end of the bar: a glyph, an optional value, and a
// stadium behind them that lights up on hover.
//
// Everything in the status cluster is one of these, whether or not it does
// anything when clicked, so a pill that is only a readout and a pill that opens
// a menu are the same height, the same weight and the same distance apart. The
// ones that are clickable say so by lighting up under the pointer; the ones
// that are not stay flat.
//
// ── Why the width is animated ───────────────────────────────────────────
// These readouts change length constantly — an SSID appears, a battery
// estimate ticks from (1:09) to (59m), a device name arrives on the Bluetooth
// pill when a headset connects. Snapping to the new width shoves every pill to
// its left sideways by a few pixels, which is the single most distracting
// thing a bar can do, because it happens in peripheral vision while you are
// reading something else.
//
// Animating `implicitWidth` instead makes the pill grow into its new size and
// the row flow around it — the morphing that shells like caelestia are built
// around. `clip` matters here: the label text changes the instant the value
// does, while the stadium takes 500ms to catch up, so without it the new text
// hangs out of a pill that has not grown yet.

import QtQuick
import QtQuick.Layouts

Item {
    id: pill

    // The name of the menu this pill opens, "" for a plain readout. It is the
    // pill's whole configuration: a pill that opens something is interactive,
    // is drawn as a tab, and is the one the bar hands to a menu by this name
    // (see Bar.qml) — none of which is worth stating four more times per pill.
    property string menu: ""
    readonly property bool opens: menu !== ""

    // The cluster runs the full height of the bar so that the tabs among these
    // can fill it. A readout centres itself in that height instead.
    Layout.fillHeight: opens
    Layout.alignment: Qt.AlignVCenter

    property string glyph
    property string label
    // Lit permanently rather than only on hover: the state a pill is *in*,
    // as opposed to the pointer being over it. The Bluetooth pill uses it for
    // "the menu is open", and everything else leaves it false.
    property bool active: false
    property color tint: Theme.primary

    // Colours the glyph in `tint` without lighting the stadium behind it: for a
    // pill that has something to say (muted, nearly flat) rather than one that
    // has been switched on. A chip that lit up for a low battery would read as
    // a control that had been pressed.
    //
    // `tint` doubles as the alert colour, so a pill that sets `alert` should
    // set a `tint` that is not the resting red.
    property bool alert: false

    signal hoverChanged(bool hovered)

    // The width this pill is heading for, before the animation below. The bar
    // measures the row from these rather than from the live widths, so that a
    // menu hanging off a pill has an unmoving number to animate towards — see
    // `menuGap` in Bar.qml and the Behaviors in Chrome.qml.
    readonly property real targetWidth: row.implicitWidth + Tokens.padding.medium * 2

    implicitWidth: targetWidth
    implicitHeight: 22
    clip: true

    Behavior on implicitWidth { Anim { motion: Motion.spatial } }

    Rectangle {
        anchors.fill: parent

        // A stadium for the readouts — `full` resolves to whatever makes the
        // ends semicircular at this height, so the shape stays right if the bar
        // is ever made taller.
        //
        // A pill that opens something is a tab instead: full bar height, top
        // corners rounded, bottom edge square and flush, exactly like the
        // focused workspace chip at the other end of the bar, and for the same
        // reason — a tab is attached to something below it. There it is the
        // window; here it is the menu hanging off the bar's underside, and the
        // tab is what says the two are one thing rather than a highlight that
        // happens to sit above a panel.
        radius: pill.opens ? 0 : Tokens.rounding.full
        topLeftRadius: pill.opens ? 2 : radius
        topRightRadius: pill.opens ? 2 : radius
        bottomLeftRadius: pill.opens ? 0 : radius
        bottomRightRadius: pill.opens ? 0 : radius

        // Filled solid when lit, like the workspace tab, and for the same reason:
        // it is not a hint that something is hovered, it is the state the desktop
        // is in.
        //
        // Always the accent, never `tint`. The tab is the head of the menu hanging
        // below it — the menu's own host is painted in the accent and the tab runs
        // into it through the tongue — so a pill that tinted its tab would break
        // that into two colours. `tint` stays what it was: the colour this pill
        // shouts in, which for the volume pill is amber, and which has nothing to
        // do with the menu it opens.
        color: pill.active
            ? Theme.primary
            : (hover.hovered && pill.opens ? Qt.alpha(Theme.primary, 0.10) : "transparent")

        Behavior on color { CAnim { motion: Motion.fastEffect } }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Text {
            text: pill.glyph
            // The clock is a pill with nothing but a reading, the way the old
            // status line had it. Collapsed rather than left as an empty Text,
            // which would still pay for the row's spacing.
            visible: text !== ""
            // Red at rest — the same signal colour Firefox's toolbar icons
            // use, and the one thing in an otherwise entirely cyan desktop
            // that reads as a different *kind* of element rather than as more
            // chrome.
            //
            // Which means red is no longer available to raise an alarm with:
            // an alerting pill goes amber instead, because red-on-red is not a
            // warning. Anything more urgent than that has to say so with its
            // glyph — see the battery's, which switches to the struck-through
            // cell below 10%.
            // Inverted against the filled tab, as the workspace chip's label is.
            color: pill.active ? Theme.background : (pill.alert ? pill.tint : Theme.hot)
            font.family: Theme.iconFont
            font.pixelSize: Tokens.fontSize.normal

            Behavior on color { CAnim { motion: Motion.fastEffect } }
        }

        Text {
            text: pill.label
            visible: text !== ""
            color: pill.active ? Theme.background : Theme.hot
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: pill.hoverChanged(hovered)
    }
}
