// Draw the bar highlight, tongue and menu host with bloom around the panel rim.

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: chrome

    property int barHeight: 28

    property bool open: false
    property string current: ""

    property Item pills
    property Item tracked
    readonly property real trackedX: tracked ? pills.x + tracked.x : 0
    readonly property real trackedWidth: tracked ? tracked.width : 0
    property real slideX: 0
    property real slideWidth: 0
    readonly property real pillX: trackedX + slideX
    readonly property real pillWidth: trackedWidth + slideWidth
    readonly property real pillGap: width - pillX - pillWidth

    function findPill(name) {
        if (!pills) return null;
        for (let i = 0; i < pills.children.length; i++)
            if (pills.children[i].menu === name) return pills.children[i];
        return null;
    }

    onCurrentChanged: {
        const next = findPill(current);
        if (next === tracked) return;
        const fromX = pillX, fromWidth = pillWidth;
        tracked = next;
        slide.stop();
        if (reveal > 0.01 && next && fromWidth > 0) {
            slideX = fromX - trackedX;
            slideWidth = fromWidth - trackedWidth;
            slide.start();
        } else {
            slideX = 0;
            slideWidth = 0;
        }
    }

    ParallelAnimation {
        id: slide
        Anim { target: chrome; property: "slideX"; to: 0; motion: Motion.spatial }
        Anim { target: chrome; property: "slideWidth"; to: 0; motion: Motion.spatial }
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

    // The panel's bloom, drawn under the panel itself.
    MultiEffect {
        source: panel
        anchors.fill: panel
        shadowEnabled: true
        shadowColor: Theme.primary
        blurMax: 48
        shadowBlur: 1.0
        shadowOpacity: 0.15
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
    }

    Shape {
        id: panel
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // The panel outline continues the bar's bottom edge around the menu.
            id: outline

            readonly property real edge: chrome.barHeight - 0.5
            readonly property real left: chrome.boxX + 0.5
            readonly property real right: chrome.boxX + chrome.boxWidth - 0.5
            readonly property real bottom: edge + chrome.boxHeight
            readonly property real radius: Math.max(0, chrome.boxRadius - 0.5)

            // A lit turquoise pane with a whiter core inside the primary bloom.
            fillColor: Qt.tint(Theme.panel, Qt.alpha(Theme.primary, 0.2))
            strokeColor: Qt.lighter(Theme.primary, 1.35)
            strokeWidth: 1

            startX: -2
            startY: outline.edge
            PathLine { x: outline.left; y: outline.edge }
            PathLine { x: outline.left; y: outline.bottom - outline.radius }
            PathArc {
                x: outline.left + outline.radius; y: outline.bottom
                radiusX: outline.radius; radiusY: outline.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.right - outline.radius; y: outline.bottom }
            PathArc {
                x: outline.right; y: outline.bottom - outline.radius
                radiusX: outline.radius; radiusY: outline.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.right; y: outline.edge }
            PathLine { x: chrome.width + 2; y: outline.edge }
            PathLine { x: chrome.width + 2; y: -2 }
            PathLine { x: -2; y: -2 }
        }
    }

    // Scanlines, a light along the bar's top edge and a rim light in the menu frame.
    Item {
        id: lighting
        visible: false
        anchors.fill: parent

        readonly property int rim: chrome.frame
        readonly property color lit: Qt.alpha(Theme.primary, 0.35)

        Repeater {
            model: Math.floor(lighting.height / 3)
            Rectangle {
                y: index * 3
                width: lighting.width
                height: 1
                color: Qt.alpha(Theme.primary, 0.10)
            }
        }

        Rectangle {
            width: lighting.width
            height: lighting.rim
            gradient: Gradient {
                GradientStop { position: 0; color: lighting.lit }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Rectangle {
            x: chrome.boxX
            y: chrome.barHeight
            width: lighting.rim
            height: chrome.boxHeight
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: lighting.lit }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Rectangle {
            x: chrome.boxX + chrome.boxWidth - lighting.rim
            y: chrome.barHeight
            width: lighting.rim
            height: chrome.boxHeight
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: lighting.lit }
            }
        }

        Rectangle {
            x: chrome.boxX
            y: chrome.barHeight + chrome.boxHeight - lighting.rim
            width: chrome.boxWidth
            height: Math.min(lighting.rim, chrome.boxHeight)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: lighting.lit }
            }
        }
    }

    ShaderEffectSource {
        id: panelMask
        sourceItem: panel
        visible: false
    }

    MultiEffect {
        source: lighting
        anchors.fill: lighting
        maskEnabled: true
        maskSource: panelMask
    }

    Shape {
        id: indicator
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            // The accent tab and menu host share one filled outline.
            id: accent

            readonly property real top: chrome.hostTop
            readonly property real bottom: chrome.hostTop + chrome.hostVisibleHeight
            readonly property real left: chrome.hostLeft
            readonly property real right: chrome.hostRight
            readonly property real tabLeft: chrome.hostLeft + chrome.tongueX
            readonly property real tabRight: accent.tabLeft + chrome.pillWidth

            readonly property real radius:
                Math.min(chrome.corner, chrome.hostVisibleHeight / 2)
            readonly property real topLeftRadius:
                Math.min(accent.radius, chrome.tongueX)
            readonly property real topRightRadius:
                Math.min(accent.radius, chrome.liveInset)

            fillColor: Qt.alpha(Theme.primary, Math.min(1, chrome.grow))
            strokeWidth: -1

            startX: accent.tabLeft
            startY: 0
            PathLine { x: accent.tabRight; y: 0 }
            PathLine { x: accent.tabRight; y: accent.top }
            PathLine {
                x: accent.right - accent.topRightRadius; y: accent.top
            }
            PathArc {
                x: accent.right; y: accent.top + accent.topRightRadius
                radiusX: accent.topRightRadius
                radiusY: accent.topRightRadius
            }
            PathLine { x: accent.right; y: accent.bottom - accent.radius }
            PathArc {
                x: accent.right - accent.radius; y: accent.bottom
                radiusX: accent.radius; radiusY: accent.radius
            }
            PathLine { x: accent.left + accent.radius; y: accent.bottom }
            PathArc {
                x: accent.left; y: accent.bottom - accent.radius
                radiusX: accent.radius; radiusY: accent.radius
            }
            PathLine { x: accent.left; y: accent.top + accent.topLeftRadius }
            PathArc {
                x: accent.left + accent.topLeftRadius; y: accent.top
                radiusX: accent.topLeftRadius
                radiusY: accent.topLeftRadius
            }
            PathLine { x: accent.tabLeft; y: accent.top }
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
