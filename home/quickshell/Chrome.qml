// Everything the shell draws, as one shape.
//
// The bar's field, the line along its underside, the box an open menu hangs in
// and the accent column running down into it are not four things that have been
// lined up with each other — they are two paths in one Shape, and there is no
// arrangement of them that could come apart, because there is no arrangement.
//
// This is why the bar and the menus are one window (see Bar.qml). While they
// were two layer surfaces the bar's line had to be *erased* under an open menu
// by painting a rectangle of the bar's own colour over it, since the menu's
// surface began below the bar and could not reach the line it was interrupting.
// In one surface there is nothing to erase: the contour simply goes somewhere
// else.
//
// ── The two paths ───────────────────────────────────────────────────────
// A filled path has exactly one fill colour, so the fewest paths this can be
// is two — one per colour — and it is two:
//
//   · the panel — the dark ground, filled and outlined. Its outline *is* the
//     bar's bottom edge: it comes in from off-surface at the left, runs along
//     the underside of the bar, turns down at the open box, goes around it and
//     comes back up, and carries on to off-surface at the right. The bar and
//     the box are one filled region, so the box is not a thing under the bar,
//     it is the bar reaching down.
//   · the indicator — the accent, filled only. The tongue and the panel the
//     menu stands on, as one outline: a rounded panel with a pill-wide tab
//     standing out of its top edge, up to the bar's underside, where the lit
//     pill continues it.
//
// The three sides of the panel path that are not the bar's edge — the top and
// the two ends — are traced two pixels outside the surface, so the stroke that
// runs along them lands where nothing is drawn. Only the underside is a line.
//
// ── The reveal ──────────────────────────────────────────────────────────
// The box grows out of the bar rather than fading in over it, and that is
// forced by the above rather than chosen for its own sake: the bar and the box
// are one filled region, and one region cannot be opaque at the top and
// half-transparent below. So the reveal is geometry — `grow` scales the box's
// height and the frame's two horizontal margins together, and at zero the
// contour is a straight line with no box in it at all.
//
// It is also the better animation, which is a happy accident. Nothing is ever
// composited at partial opacity over the desktop, so the frame never goes
// milky halfway through; and the bar's edge visibly stretching down into a box
// is the thing itself rather than a picture of it.
//
// Anything placed inside stands on the accent, so it has to be drawn inverted —
// dark ink on a bright ground. See Chip.qml and DeviceRow.qml.

import QtQuick
import QtQuick.Shapes

Item {
    id: chrome

    // ── What it is told ─────────────────────────────────────────────────
    // How tall the bar's own strip is; everything below it is menu.
    property int barHeight: 28

    property bool open: false
    // Which page is shown. Kept *set* through the close — the box on its way
    // back into the bar still has to know what it is closing on.
    property string current: ""

    // Where the shown pill is, measured from the right edge of the screen, and
    // how wide it is. Target numbers, not live ones: the pills animate their
    // own widths when a label changes (see StatusPill.qml), and a Behavior fed
    // from something already in motion retargets every frame and restarts every
    // frame. Fed from the targets, every move — a label growing, a switch to
    // another pill — is one animation started at one instant, on the same curve
    // and duration as the pill's own width animation, so the tab and the pill
    // above it travel together to the pixel.
    property real pillGap: 0
    property real pillWidth: 0

    // Disabled while the box is closed, like the size below: a shut box snaps
    // to wherever the next open is, rather than sweeping along the bar from the
    // pill it was last hung on.
    Behavior on pillGap {
        enabled: chrome.reveal > 0.01
        Anim { motion: Motion.spatial }
    }
    Behavior on pillWidth {
        enabled: chrome.reveal > 0.01
        Anim { motion: Motion.spatial }
    }

    // The menus. Each is a MenuPage; they stand on the indicator, and exactly
    // one is shown at a time, named by `current`.
    default property alias content: hostContent.data

    // ── Metrics ─────────────────────────────────────────────────────────
    readonly property int frame: Tokens.spacing.medium
    readonly property int pad: Tokens.padding.medium
    readonly property int corner: Tokens.rounding.medium

    // How far in from the indicator's right edge the tab sits when there is
    // room: enough that its side clears the rounded corner. When there is not —
    // a collapsed menu barely wider than its pill, or a pill hard against the
    // screen edge — the inset gives way smoothly, and the corner rounding gives
    // way with it.
    readonly property int tongueInset: corner + frame

    // ── The pages, and the worst case over all of them ──────────────────
    readonly property Item currentPage: {
        const pages = hostContent.children;
        for (let i = 0; i < pages.length; i++)
            if (pages[i].name === current) return pages[i];
        return null;
    }
    readonly property int contentWidth: currentPage ? currentPage.contentWidth : 0
    readonly property int contentHeight: currentPage ? currentPage.contentHeight : 0
    readonly property int maxContentHeight: {
        let max = 0;
        const pages = hostContent.children;
        for (let i = 0; i < pages.length; i++)
            max = Math.max(max, pages[i].maxContentHeight);
        return max;
    }

    // What the window has to be tall enough to hold: the largest menu, plus
    // slack for the overshoot at the end of the reveal. See Bar.qml.
    readonly property int maxBoxHeight:
        maxContentHeight + pad * 2 + frame * 2 + 24

    // ── The animated inputs ─────────────────────────────────────────────
    // Four numbers move: the two pill values above, the content size here, and
    // the reveal. Every coordinate in the two paths is a plain live function of
    // those four, so there is exactly one animation per changing input and
    // nothing ever chases a moving target.
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        Anim { motion: chrome.open ? Motion.fastSpatial : Motion.standard }
    }

    // The opening curve overshoots, which here is the box unrolling a little
    // past its height and settling back. Only the floor is clamped: a curve
    // that undershot below zero would turn the box inside out.
    readonly property real grow: Math.max(0, reveal)

    // Disabled while shut, so the first reveal after a switch presents the new
    // menu rather than replaying its resize.
    property real smoothContentWidth: contentWidth
    property real smoothContentHeight: contentHeight

    // The spatial curve overshoots, which is right for growth and wrong for
    // shrinking: overshooting a shrink means sailing *below* the target, and on
    // a large collapse the box squeezes past its new size and springs back,
    // which reads as the menu being swapped for a smaller one. `motion` is read
    // when the animation starts, while the property still holds its old value
    // and the target already holds the new one, so comparing the two is a
    // reliable test of which way this is going.
    Behavior on smoothContentWidth {
        enabled: chrome.reveal > 0.01
        Anim {
            motion: chrome.contentWidth < chrome.smoothContentWidth
                ? Motion.standard : Motion.fastSpatial
        }
    }
    Behavior on smoothContentHeight {
        enabled: chrome.reveal > 0.01
        Anim {
            motion: chrome.contentHeight < chrome.smoothContentHeight
                ? Motion.standard : Motion.fastSpatial
        }
    }

    // ── The geometry, derived live ──────────────────────────────────────
    // The indicator is never wider than the pill it stands for: its floor is
    // exactly `pillWidth`, so a menu whose contents ask for less collapses to a
    // straight pill-wide column under its pill rather than to a blob that
    // sticks out past it.
    readonly property real hostWidth: Math.max(smoothContentWidth + pad * 2,
                                               pillWidth)
    readonly property real hostHeight: smoothContentHeight + pad * 2

    readonly property real boxWidth: hostWidth + frame * 2
    readonly property real boxHeight: (hostHeight + frame * 2) * grow

    // The frame's horizontal margins scale with the reveal along with
    // everything else, so the box keeps its proportions the whole way out
    // instead of arriving as a dark slot that the accent then fills.
    readonly property real frameV: frame * grow
    readonly property real hostTop: barHeight + frameV
    readonly property real hostVisibleHeight: hostHeight * grow

    // The tab's inset from the indicator's right edge: the full `tongueInset`
    // when the box and the screen leave room for it, sliding smoothly to zero
    // when they do not. At zero the tab is flush with the indicator's side and
    // the corner under it is square, which is the collapsed column.
    readonly property real liveInset:
        Math.max(0, Math.min(tongueInset,
                             Math.min(hostWidth - pillWidth, pillGap - frame)))
    readonly property real tongueX: hostWidth - liveInset - pillWidth

    // The box is placed so the tab lands exactly under the pill. Clamped at the
    // screen edge, though the bar's own right margin is set to `frame` so that
    // the last pill never needs the clamp — see the cluster in Bar.qml.
    readonly property real rightOffset:
        Math.max(0, pillGap - liveInset - frame)
    readonly property real boxX: width - rightOffset - boxWidth

    readonly property real hostLeft: boxX + frame
    readonly property real hostRight: boxX + boxWidth - frame

    // The box's bottom corners. Read by the path below *and* by the input
    // region in Bar.qml, which is the point: a region that squared these off
    // would take the pointer in two corners that are not part of the shape.
    // A box shallower than a corner gets a fully rounded bottom rather than a
    // corner it has no room for.
    readonly property real boxRadius: Math.min(corner, boxHeight)

    // ── Anchors for pinned controls, in content coordinates ─────────────
    // A page whose contents change size should pin whatever control the pill
    // stands for to one of these, so that the one thing the pointer is already
    // on stays put while the rest of the menu grows or shrinks around it.
    //
    // `pillAnchor` is `pad` in from the pill's left edge — numerically just
    // `tongueX`, and that equality is the whole point. When a menu collapses,
    // its content ends up at the collapsed column's origin, which sits `pad` in
    // from the indicator's left edge, and that edge lands on the pill's left
    // edge (the tab's inset reaches zero exactly as the column forms). So a
    // chip pinned here occupies the same screen pixel while the menu is open,
    // at every frame of the collapse, and in the collapsed column. Anchors that
    // were *almost* right each left a residual of a few pixels between where
    // the chip flew and where the collapse deposited it, and a button that
    // steps sideways as the menu settles reads as a button that moved.
    readonly property real pillAnchor: tongueX

    // `pillRight` is the pill's *right* edge. For a menu that never collapses
    // it is the steadier anchor, because the pills are right-anchored in the
    // bar's cluster: a pill whose label changes width does so at its left edge,
    // and this expression contains no `pillWidth` term at all. The volume chip
    // pins to it, since muting rewrites that pill's label at the very moment
    // the chip is clicked.
    readonly property real pillRight: hostWidth - liveInset - pad

    // ── The shape ───────────────────────────────────────────────────────
    Shape {
        anchors.fill: parent
        // Its antialiasing is what lets a 1px stroke here read as the same
        // weight of line the shell draws everywhere else.
        preferredRendererType: Shape.CurveRenderer

        // ── The panel ───────────────────────────────────────────────────
        // The dark ground and the line along the bar's underside, as one
        // thing. The half pixels put the 1px stroke on the pixel grid rather
        // than across two of them; the ±2 at the top and the two ends put the
        // rest of the stroke outside the surface, where it is never drawn.
        ShapePath {
            id: panel

            fillColor: Theme.panel
            strokeColor: Theme.primary
            strokeWidth: 1

            // The centre line of the bar's edge: a 1px stroke here covers the
            // bar's last row exactly.
            readonly property real edge: chrome.barHeight - 0.5
            readonly property real left: chrome.boxX + 0.5
            readonly property real right: chrome.boxX + chrome.boxWidth - 0.5
            readonly property real bottom: edge + chrome.boxHeight
            // Pulled in by the half pixel the stroke's centre line is inset.
            readonly property real radius: Math.max(0, chrome.boxRadius - 0.5)

            startX: -2
            startY: panel.edge
            PathLine { x: panel.left; y: panel.edge }
            PathLine { x: panel.left; y: panel.bottom - panel.radius }
            PathArc {
                x: panel.left + panel.radius; y: panel.bottom
                radiusX: panel.radius; radiusY: panel.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: panel.right - panel.radius; y: panel.bottom }
            PathArc {
                x: panel.right; y: panel.bottom - panel.radius
                radiusX: panel.radius; radiusY: panel.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: panel.right; y: panel.edge }
            PathLine { x: chrome.width + 2; y: panel.edge }
            PathLine { x: chrome.width + 2; y: -2 }
            PathLine { x: -2; y: -2 }
        }

        // ── The indicator ───────────────────────────────────────────────
        // The tongue and the panel the menu stands on, as one outline. The two
        // top corners are only as round as the space beside the tab allows,
        // shrinking to square exactly as the tab reaches the edge, so the tab's
        // side never cuts across a curve; and every radius is capped by the
        // height so that a box on its way out never rounds more than it has.
        //
        // At `grow` of zero the top and the bottom are the same line and this
        // encloses nothing, which is how a shut menu draws no indicator without
        // anything having to be switched off.
        ShapePath {
            id: indicator

            fillColor: Theme.primary
            // Negative disables stroking outright; 0 still draws a hairline.
            // The panel above carries the one outline in this shape.
            strokeWidth: -1

            readonly property real top: chrome.hostTop
            readonly property real bottom: chrome.hostTop + chrome.hostVisibleHeight
            readonly property real left: chrome.hostLeft
            readonly property real right: chrome.hostRight
            readonly property real tabLeft: chrome.hostLeft + chrome.tongueX
            readonly property real tabRight: indicator.tabLeft + chrome.pillWidth

            readonly property real radius:
                Math.min(chrome.corner, chrome.hostVisibleHeight / 2)
            readonly property real topLeftRadius:
                Math.min(indicator.radius, chrome.tongueX)
            readonly property real topRightRadius:
                Math.min(indicator.radius, chrome.liveInset)

            startX: indicator.tabLeft
            startY: chrome.barHeight
            PathLine { x: indicator.tabRight; y: chrome.barHeight }
            PathLine { x: indicator.tabRight; y: indicator.top }
            PathLine {
                x: indicator.right - indicator.topRightRadius; y: indicator.top
            }
            PathArc {
                x: indicator.right; y: indicator.top + indicator.topRightRadius
                radiusX: indicator.topRightRadius
                radiusY: indicator.topRightRadius
            }
            PathLine { x: indicator.right; y: indicator.bottom - indicator.radius }
            PathArc {
                x: indicator.right - indicator.radius; y: indicator.bottom
                radiusX: indicator.radius; radiusY: indicator.radius
            }
            PathLine { x: indicator.left + indicator.radius; y: indicator.bottom }
            PathArc {
                x: indicator.left; y: indicator.bottom - indicator.radius
                radiusX: indicator.radius; radiusY: indicator.radius
            }
            PathLine { x: indicator.left; y: indicator.top + indicator.topLeftRadius }
            PathArc {
                x: indicator.left + indicator.topLeftRadius; y: indicator.top
                radiusX: indicator.topLeftRadius
                radiusY: indicator.topLeftRadius
            }
            PathLine { x: indicator.tabLeft; y: indicator.top }
        }
    }

    // ── The contents ────────────────────────────────────────────────────
    // Standing on the indicator, inset by `pad`, and clipped to however much of
    // it is out of the bar so far. `hostContent` keeps its full height inside
    // the clip, so a page lays itself out once and is revealed rather than
    // relaid every frame; the top edge slides down with the frame's margin,
    // which is the same short drop the box used to make as a whole.
    Item {
        id: hostClip

        x: chrome.hostLeft + chrome.pad
        y: chrome.hostTop + chrome.pad
        width: Math.max(0, chrome.hostWidth - chrome.pad * 2)
        height: Math.max(0, chrome.hostVisibleHeight - chrome.pad * 2)
        clip: true

        opacity: Math.min(1, chrome.reveal)
        visible: opacity > 0 && height > 0

        Item {
            id: hostContent
            width: hostClip.width
            height: Math.max(0, chrome.hostHeight - chrome.pad * 2)
        }
    }
}
