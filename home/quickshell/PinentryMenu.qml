// gpg-agent passphrase prompt. Enter answers, Escape or the close chip cancels.

import QtQuick
import QtQuick.Layouts

MenuPage {
    id: menu

    name: "pinentry"

    readonly property int gap: Tokens.spacing.small

    contentWidth: 360
    contentHeight: column.implicitHeight
    maxContentHeight: 240

    // Never keep a typed passphrase past its prompt.
    onActiveChanged: {
        field.text = "";
        if (active) field.forceActiveFocus();
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: menu.gap

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.size.control

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Pinentry.title || "gpg-agent"
                font.pixelSize: Tokens.fontSize.larger
            }

            Chip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                glyph: String.fromCodePoint(0xf0156)  // md-close
                onToggled: Pinentry.cancel()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: Pinentry.description
            wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: Pinentry.error
            wrapMode: Text.Wrap
            color: Theme.hot
        }

        Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.size.row

            Icon {
                id: label
                anchors.left: parent.left
                anchors.leftMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(0xf033e)  // md-lock
                color: Theme.primary
            }

            TextInput {
                id: field
                anchors.left: label.right
                anchors.right: parent.right
                anchors.leftMargin: Tokens.spacing.small
                anchors.rightMargin: Tokens.spacing.medium
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                echoMode: TextInput.Password
                color: Theme.primary
                selectionColor: Theme.primary
                selectedTextColor: Theme.background
                font.family: Theme.fontFamily
                font.pixelSize: Tokens.fontSize.small

                function submit() {
                    const pin = text;
                    text = "";
                    Pinentry.answer(pin);
                }
                Keys.onReturnPressed: submit()
                Keys.onEnterPressed: submit()
                Keys.onEscapePressed: Pinentry.cancel()
            }
        }
    }
}
