import QtQuick
import Quickshell

// Keyboard layout in the bar (EN, TH, ...). Click: layout panel, right click: next layout.
// State and settings live in the KeyboardSettings singleton.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    required property var barWindow

    Row {
        id: row
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f030c}"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: KeyboardSettings.activeCode
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.text
        }
    }

    KeyboardPopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
    }

    // Left: layout panel, right: next layout
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                popup.toggle();
            else
                KeyboardSettings.next();
        }
    }
}
