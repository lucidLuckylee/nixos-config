// The launcher's text field and matching commands, laid out along the bar.
// Left/Right pick a match, Tab completes it, Enter runs it (Shift+Enter runs
// the typed text as is) and Escape closes.

import QtQuick

Item {
    id: launcher

    property bool active: false
    visible: active

    // Exact matches first, then prefixes, then substrings, like dmenu; each
    // group keeps the launcher's recently-used order.
    readonly property var matches: {
        const query = field.text.toLowerCase();
        if (query === "") return Launcher.ordered;

        const exact = [], prefix = [], rest = [];
        for (const command of Launcher.ordered) {
            const lower = command.toLowerCase();
            if (lower === query) exact.push(command);
            else if (lower.startsWith(query)) prefix.push(command);
            else if (lower.includes(query)) rest.push(command);
        }
        return exact.concat(prefix, rest);
    }

    onActiveChanged: {
        field.text = "";
        if (active) field.forceActiveFocus();
    }

    // A recessed patch of the bar: its lit pane and scanlines show through.
    Rectangle {
        id: box
        width: 200
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        color: Qt.alpha(Theme.background, 0.35)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.35)

        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small
            verticalAlignment: TextInput.AlignVCenter
            clip: true

            color: Theme.primary
            selectionColor: Theme.primary
            selectedTextColor: Theme.background
            font.family: Theme.fontFamily
            font.pixelSize: Tokens.fontSize.small

            onTextChanged: list.currentIndex = 0
            // Sway took the keyboard away, e.g. through a binding that moved focus.
            onActiveFocusChanged: if (!activeFocus && launcher.active) Launcher.open = false

            function submit(event) {
                const typed = event.modifiers & Qt.ShiftModifier || list.count === 0;
                Launcher.run(typed ? text : launcher.matches[list.currentIndex]);
            }
            Keys.onReturnPressed: event => submit(event)
            Keys.onEnterPressed: event => submit(event)
            Keys.onEscapePressed: Launcher.open = false
            Keys.onLeftPressed: list.decrementCurrentIndex()
            Keys.onRightPressed: list.incrementCurrentIndex()
            Keys.onTabPressed: {
                if (list.count > 0) text = launcher.matches[list.currentIndex];
            }
        }
    }

    ListView {
        id: list
        anchors.left: box.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        interactive: false
        model: launcher.matches

        // Jump to the selection; the built-in tracking crawls at a fixed velocity.
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: entry
            required property string modelData
            required property int index

            width: Math.max(24, label.implicitWidth + 14)
            height: list.height

            Text {
                id: label
                anchors.centerIn: parent
                text: entry.modelData
                color: entry.ListView.isCurrentItem ? Theme.hot : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small
            }

            TapHandler { onTapped: Launcher.run(entry.modelData) }
        }
    }
}
