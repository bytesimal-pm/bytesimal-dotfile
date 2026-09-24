import QtQuick
import Quickshell

// Keyboard panel under the bar's keyboard item: pick a layout, open the settings window
BarPopup {
    id: popup
    alignRight: true

    readonly property var kbd: KeyboardSettings

    onAboutToOpen: kbd.refresh()

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.text
        elide: Text.ElideRight
    }

    SectionLabel { text: "KEYBOARD LAYOUT" }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: popup.kbd.layouts

            ListRow {
                id: row
                required property var modelData
                required property int index

                width: parent.width
                height: 30
                active: index === popup.kbd.activeIndex
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) popup.kbd.switchTo(row.index);
                }

                Label {
                    id: code
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    text: popup.kbd.code(row.modelData.layout)
                    font.bold: true
                    color: row.active ? "#000000" : Theme.dim
                }

                Label {
                    anchors.left: code.right
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.kbd.nameOf(row.modelData)
                    font.bold: row.active
                    color: row.active ? "#000000" : Theme.text
                }
            }
        }
    }

    Label {
        width: parent.width
        font.pixelSize: Theme.fontSize - 1
        color: Theme.dim
        text: popup.kbd.layouts.length < 2 ? "Add more layouts in Keyboard settings"
            : popup.kbd.settings.switch !== "" ? "Switch with " + popup.kbd.shortcutName() + " or right-click"
            : "Switch by right-clicking the bar icon"
    }

    Separator { width: parent.width }

    TextButton {
        text: "\u{f0493}  Keyboard settings"
        onClicked: {
            popup.visible = false;
            popup.kbd.open();
        }
    }
}
