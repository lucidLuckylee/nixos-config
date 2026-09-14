// Draw the bar, menu frame and accent indicator as one continuous shape.

import QtQuick
import QtQuick.Shapes

Item {
    id: chrome

    property int barHeight: 28

    property bool open: false
    property string current: ""

    property real pillGap: 0
    property real pillWidth: 0

    // Animate target geometry once; snap to the next pill while closed.
    Behavior on pillGap {
        enabled: chrome.reveal > 0.01
        Anim { motion: Motion.spatial }
    }
    Behavior on pillWidth {
        enabled: chrome.reveal > 0.01
        Anim { motion: Motion.spatial }
    }

    // MenuPage children live inside the clipped content host.
    default property alias content: hostContent.data

    readonly property int frame: Tokens.spacing.medium
    readonly property int pad: Tokens.padding.medium
    readonly property int corner: Tokens.rounding.medium

    readonly property int tongueInset: corner + frame

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

    // Leave space for the opening animation to overshoot.
    readonly property int maxBoxHeight:
        maxContentHeight + pad * 2 + frame * 2 + 24

    property real reveal: open ? 1 : 0
    Behavior on reveal {
        Anim { motion: chrome.open ? Motion.fastSpatial : Motion.standard }
    }

    // Clamp only the floor so the opening overshoot remains visible.
    readonly property real grow: Math.max(0, reveal)

    property real smoothContentWidth: contentWidth
    property real smoothContentHeight: contentHeight

    // Shrink without overshoot to avoid squeezing below the new content size.
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

    readonly property real hostWidth: Math.max(smoothContentWidth + pad * 2,
                                               pillWidth)
    readonly property real hostHeight: smoothContentHeight + pad * 2

    readonly property real boxWidth: hostWidth + frame * 2
    readonly property real boxHeight: (hostHeight + frame * 2) * grow

    readonly property real frameV: frame * grow
    readonly property real hostTop: barHeight + frameV
    readonly property real hostVisibleHeight: hostHeight * grow

    // Let the tab inset collapse when its pill or the screen edge leaves no room.
    readonly property real liveInset:
        Math.max(0, Math.min(tongueInset,
                             Math.min(hostWidth - pillWidth, pillGap - frame)))
    readonly property real tongueX: hostWidth - liveInset - pillWidth

    readonly property real rightOffset:
        Math.max(0, pillGap - liveInset - frame)
    readonly property real boxX: width - rightOffset - boxWidth

    readonly property real hostLeft: boxX + frame
    readonly property real hostRight: boxX + boxWidth - frame

    // Share corner geometry with the window input mask.
    readonly property real boxRadius: Math.min(corner, boxHeight)

    // Content coordinates for controls pinned to the pill through menu resizing.
    readonly property real pillAnchor: tongueX

    // The right edge stays steady when a status label changes width.
    readonly property real pillRight: hostWidth - liveInset - pad

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // The panel outline continues the bar's bottom edge around the menu.
            id: panel

            fillColor: Theme.panel
            strokeColor: Theme.primary
            strokeWidth: 1

            readonly property real edge: chrome.barHeight - 0.5
            readonly property real left: chrome.boxX + 0.5
            readonly property real right: chrome.boxX + chrome.boxWidth - 0.5
            readonly property real bottom: edge + chrome.boxHeight
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

        ShapePath {
            // The accent tab and menu host share one filled outline.
            id: indicator

            fillColor: Theme.primary
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

    Item {
        // Reveal full-size contents by clipping, without relaying them out every frame.
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
