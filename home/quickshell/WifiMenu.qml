// Wi-Fi radio, scanning and network actions. Clicking a network connects or
// disconnects it; a secured network without a saved password asks for one here,
// since nothing else answers NetworkManager's request for secrets.

import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "wifi"

    readonly property var device: Status.wifiDevice
    readonly property bool live: Status.wifiLive

    readonly property int gap: Tokens.spacing.small
    readonly property int maxRows: 5
    readonly property int rows: live ? Math.min(maxRows, Math.max(1, networks.length)) : 0

    // The network whose password is being typed, and the one being joined.
    property var asking: null
    property var joining: null
    property bool joinedWithPassword: false
    property string notice: ""

    typing: asking !== null && active

    contentWidth: live ? 300 : Tokens.size.chip
    contentHeight: asking ? promptHeight : listHeight(rows)
    maxContentHeight: Math.max(listHeight(maxRows), promptHeight)

    readonly property int noticeHeight: notice !== "" ? gap + Tokens.size.control : 0
    readonly property int promptHeight:
        Tokens.size.control + 2 * (gap + Tokens.size.row) + noticeHeight

    function listHeight(n) {
        return Tokens.size.control + (n > 0 ? n * (Tokens.size.row + gap) : 0) + noticeHeight;
    }

    readonly property var networks: {
        if (!live || !device) return [];

        return [...device.networks.values]
            .filter(n => n.name)
            .sort((a, b) =>
                (b.connected - a.connected)
                || (b.known - a.known)
                || (Status.strength(b) - Status.strength(a))
                || a.name.localeCompare(b.name)
            );
    }

    function takesPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae]
            .includes(network.security);
    }

    function activate(network) {
        notice = "";
        if (network.connected) {
            network.disconnect();
        } else if (!network.known && takesPassword(network)) {
            ask(network, "");
        } else {
            join(network, false);
            network.connect();
        }
    }

    function join(network, withPassword) {
        joining = network;
        joinedWithPassword = withPassword;
    }

    function ask(network, message) {
        asking = network;
        notice = message;
        field.text = "";
        field.echoMode = TextInput.Password;
        field.forceActiveFocus();
    }

    function submit() {
        if (!asking || field.text === "") return;
        notice = "";
        join(asking, true);
        asking.connectWithPsk(field.text);
        field.text = "";
        asking = null;
    }

    function cancel() {
        asking = null;
        notice = "";
        field.text = "";
    }

    onActiveChanged: if (!active) cancel()
    onLiveChanged: if (!live) cancel()

    // Without a secret agent, a missing or wrong password comes back as a
    // failure; ask for it rather than failing silently.
    Connections {
        target: menu.joining
        function onConnectionFailed(reason) {
            const network = menu.joining;
            menu.joining = null;
            if (menu.takesPassword(network) && reason !== ConnectionFailReason.WifiNetworkLost)
                menu.ask(network, menu.joinedWithPassword ? "wrong password, try again" : "");
            else
                menu.notice = "couldn't join " + network.name;
        }
        function onConnectedChanged() {
            if (menu.joining && menu.joining.connected) menu.joining = null;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: menu.gap

        RadioHeader {
            page: menu
            onGlyph: String.fromCodePoint(0xf05a9)   // md-wifi
            offGlyph: String.fromCodePoint(0xf05aa)  // md-wifi-off
            live: menu.live
            available: menu.device !== null && Networking.wifiHardwareEnabled
            scanning: menu.device !== null && menu.device.scannerEnabled

            onPowerToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            onScanToggled: menu.device.scannerEnabled = !menu.device.scannerEnabled
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            opacity: menu.live && !menu.asking ? 1 : 0
            visible: opacity > 0
            active: menu.live || opacity > 0
            Behavior on opacity { Anim { motion: Motion.fastEffect } }

            sourceComponent: networkList
        }

        // Keeps the header at the top while the list is hidden.
        Item { Layout.fillHeight: true }
    }

    Component {
        id: networkList

        ColumnLayout {
            spacing: menu.gap

            // Shows up to maxRows networks; the rest scroll.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: menu.rows * (Tokens.size.row + menu.gap) - menu.gap
                visible: menu.networks.length > 0

                Flickable {
                    id: scroller

                    readonly property bool scrollable: contentHeight > height

                    anchors.fill: parent
                    anchors.rightMargin: scrollable ? Tokens.spacing.small : 0
                    contentHeight: rowColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Connections {
                        target: menu
                        function onActiveChanged() { if (menu.active) scroller.contentY = 0; }
                    }

                    ColumnLayout {
                        id: rowColumn
                        width: scroller.width
                        spacing: menu.gap

                        Repeater {
                            model: menu.networks

                            MenuRow {
                                id: row

                                required property var modelData
                                required property int index

                                readonly property real strength: Status.strength(modelData)
                                readonly property bool busy: modelData.stateChanging

                                page: menu
                                entryIndex: index
                                current: modelData.connected
                                clickable: !busy
                                onClicked: menu.activate(row.modelData)

                                Icon {
                                    text: Status.wifiGlyph(row.strength)
                                    color: row.busy ? Theme.warm
                                         : row.current ? Theme.primary : Qt.alpha(Theme.background, 0.75)
                                    Behavior on color { CAnim { motion: Motion.fastEffect } }
                                    Pulse on opacity { running: row.busy }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Tokens.spacing.extraSmall
                                    text: row.modelData.name
                                    elide: Text.ElideRight
                                    color: row.current
                                        ? Theme.primary
                                        : Qt.alpha(Theme.background, row.modelData.known ? 1 : 0.7)
                                }

                                // A lock marks networks that will ask for a password.
                                Icon {
                                    visible: !row.modelData.known && menu.takesPassword(row.modelData)
                                    text: String.fromCodePoint(0xf033e)  // md-lock
                                    color: Qt.alpha(Theme.background, 0.5)
                                    font.pixelSize: Tokens.fontSize.small
                                }

                                Label {
                                    text: Math.round(row.strength * 100) + "%"
                                    rightPadding: Tokens.spacing.extraSmall
                                    color: row.current
                                        ? Qt.alpha(Theme.primary, 0.8)
                                        : Qt.alpha(Theme.background, 0.6)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: scroller.scrollable
                    anchors.right: parent.right
                    y: scroller.visibleArea.yPosition * parent.height
                    width: 2
                    height: scroller.visibleArea.heightRatio * parent.height
                    radius: 1
                    color: Qt.alpha(Theme.background, 0.4)
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.size.row
                verticalAlignment: Text.AlignVCenter
                visible: menu.networks.length === 0
                color: Qt.alpha(Theme.background, 0.7)
                text: menu.device && menu.device.scannerEnabled
                    ? "scanning…" : "no networks"
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.size.control
                verticalAlignment: Text.AlignVCenter
                visible: menu.notice !== ""
                text: menu.notice
                elide: Text.ElideRight
                color: Theme.hot
            }

            Item { Layout.fillHeight: true }
        }
    }

    // The password prompt takes the list's place below the header.
    ColumnLayout {
        y: Tokens.size.control + menu.gap
        width: parent.width
        spacing: menu.gap

        opacity: menu.asking ? 1 : 0
        visible: opacity > 0
        enabled: menu.asking !== null
        Behavior on opacity { Anim { motion: Motion.fastEffect } }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.size.row

            Icon {
                id: lock
                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xf033e)  // md-lock
            }

            Label {
                anchors.left: lock.right
                anchors.leftMargin: Tokens.spacing.small
                anchors.right: close.left
                anchors.rightMargin: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                text: menu.asking ? menu.asking.name : ""
                elide: Text.ElideRight
                font.pixelSize: Tokens.fontSize.normal
            }

            Chip {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: String.fromCodePoint(0xf0156)  // md-close
                onToggled: menu.cancel()
            }
        }

        Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.size.row

            TextInput {
                id: field
                anchors.left: parent.left
                anchors.right: reveal.left
                anchors.leftMargin: Tokens.spacing.medium
                anchors.rightMargin: Tokens.spacing.small
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                echoMode: TextInput.Password
                color: Theme.primary
                selectionColor: Theme.primary
                selectedTextColor: Theme.background
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small

                Keys.onReturnPressed: menu.submit()
                Keys.onEnterPressed: menu.submit()
                Keys.onEscapePressed: menu.cancel()
            }

            // Show or hide the typed password.
            Icon {
                id: reveal
                anchors.right: parent.right
                anchors.rightMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter

                readonly property bool shown: field.echoMode === TextInput.Normal
                text: String.fromCodePoint(shown ? 0xf0209 : 0xf0208)  // md-eye-off / md-eye
                color: revealHover.hovered || shown ? Theme.primary : Qt.alpha(Theme.primary, 0.6)

                HoverHandler {
                    id: revealHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        field.echoMode = reveal.shown ? TextInput.Password : TextInput.Normal;
                        field.forceActiveFocus();
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.size.control
            verticalAlignment: Text.AlignVCenter
            visible: menu.notice !== ""
            text: menu.notice
            color: Theme.hot
        }
    }
}
