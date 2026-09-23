// Output volume, mute and device selection.

import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "volume"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNodeAudio audio: sink ? sink.audio : null

    readonly property real level: audio ? audio.volume : 0
    readonly property bool muted: audio !== null && audio.muted

    readonly property var outputs: {
        return Pipewire.nodes.values
            .filter(n => n.isSink && !n.isStream && n.audio)
            .sort((a, b) =>
                ((b === menu.sink) - (a === menu.sink))
                || menu.outputName(a).localeCompare(menu.outputName(b))
            )
            .slice(0, maxRows);
    }

    // Track every listed output so its audio properties are populated.
    PwObjectTracker {
        objects: menu.sink && !menu.outputs.includes(menu.sink)
            ? [menu.sink, ...menu.outputs]
            : menu.outputs
    }

    readonly property int gap: Tokens.spacing.small
    readonly property int headerHeight: 22
    readonly property int trackHeight: 22

    readonly property int rowHeight: 26
    readonly property int maxRows: 4

    // Hide output selection when there is only one device.
    readonly property int rows: outputs.length > 1 ? outputs.length : 0

    readonly property int naturalWidth: 320

    contentWidth: naturalWidth
    contentHeight: headerHeight + gap + trackHeight
        + (rows > 0 ? gap + rows * (rowHeight + gap) - gap : 0)

    maxContentHeight: headerHeight + gap + trackHeight
        + gap + maxRows * (rowHeight + gap) - gap

    function outputName(node) {
        return node.nickname || node.description || node.name;
    }

    function outputGlyph(node) {
        const name = (node.name || "").toLowerCase();
        if (name.startsWith("bluez"))
            return String.fromCodePoint(0xf02cb);  // md-headphones
        if (name.includes("hdmi") || name.includes("displayport"))
            return String.fromCodePoint(0xf0379);  // md-monitor
        return String.fromCodePoint(0xf04c3);      // md-speaker
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: menu.headerHeight

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (!menu.audio) return "--";
                    const percent = Math.round(menu.level * 100) + "%";
                    return menu.muted ? "(" + percent + ")" : percent;
                }
                color: Qt.alpha(Theme.background, menu.muted ? 0.6 : 1)
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.larger

                Behavior on color { CAnim { motion: Motion.fastEffect } }
            }

            Chip {
                // Pin mute to the pill's right edge while its label changes width.
                x: Math.max(0, Math.min(parent.width - width,
                                        menu.pillRight - width - menu.pad))
                anchors.verticalCenter: parent.verticalCenter

                glyph: {
                    if (!menu.audio || menu.muted)
                        return String.fromCodePoint(0xf075f);  // md-volume-mute
                    if (menu.level > 0.5)
                        return String.fromCodePoint(0xf057e);  // md-volume-high
                    if (menu.level > 0)
                        return String.fromCodePoint(0xf0580);  // md-volume-medium
                    return String.fromCodePoint(0xf057f);      // md-volume-low
                }
                active: menu.muted
                available: menu.audio !== null
                onToggled: menu.audio.muted = !menu.audio.muted
            }
        }

        Item {
            id: level

            Layout.fillWidth: true
            Layout.preferredHeight: menu.trackHeight

            readonly property real fraction: Math.max(0, Math.min(1, menu.level))

            // Limit direct adjustments to 100%, even if another mixer enabled amplification.
            function setFrom(x) {
                if (!menu.audio) return;
                const span = Math.max(1, width - 2);
                menu.audio.volume = Math.max(0, Math.min(1, (x - 1) / span));
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1

                border.color: Qt.alpha(Theme.background,
                    grab.containsMouse || grab.pressed ? 0.8 : 0.45)

                Behavior on border.color { CAnim { motion: Motion.fastEffect } }

                Rectangle {
                    x: 1
                    y: 1
                    height: parent.height - 2
                    width: Math.round((parent.width - 2) * level.fraction)

                    color: Qt.alpha(Theme.background, menu.muted ? 0.3 : 1)

                    Behavior on color { CAnim { motion: Motion.fastEffect } }

                    // Follow the pointer directly during a drag; animate external volume changes.
                    Behavior on width {
                        enabled: !grab.pressed
                        Anim { motion: Motion.fastEffect }
                    }
                }
            }

            // Set volume on press, without a DragHandler's initial movement threshold.
            MouseArea {
                id: grab
                anchors.fill: parent
                hoverEnabled: true
                enabled: menu.audio !== null
                cursorShape: Qt.SizeHorCursor

                onPressed: event => level.setFrom(event.x)
                onPositionChanged: event => {
                    if (pressed) level.setFrom(event.x);
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: menu.gap
            visible: menu.rows > 0

            Repeater {
                model: menu.outputs

                Item {
                    id: row

                    required property var modelData
                    readonly property bool current: modelData === menu.sink

                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        color: !row.current && hover.hovered
                            ? Qt.alpha(Theme.background, 0.10) : "transparent"

                        Behavior on color { CAnim { motion: Motion.fastEffect } }
                    }

                    Frame {
                        anchors.fill: parent
                        shown: row.current
                    }

                    HoverHandler { id: hover }

                    TapHandler {
                        enabled: !row.current
                        // Persist the preferred sink across device reconnections.
                        onTapped: Pipewire.preferredDefaultAudioSink = row.modelData
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.rightMargin: Tokens.spacing.medium
                        spacing: Tokens.spacing.small

                        Text {
                            text: menu.outputGlyph(row.modelData)
                            color: row.current ? Theme.primary : Qt.alpha(Theme.background, 0.75)
                            font.family: Theme.iconFont
                            font.pixelSize: Tokens.fontSize.normal

                            Behavior on color { CAnim { motion: Motion.fastEffect } }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.spacing.extraSmall
                            text: menu.outputName(row.modelData)
                            elide: Text.ElideMiddle
                            color: row.current ? Theme.primary : Theme.background
                            font.family: Theme.fontFamily
                            font.pixelSize: Tokens.fontSize.small
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
