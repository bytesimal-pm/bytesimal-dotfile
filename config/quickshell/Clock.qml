import QtQuick
import Quickshell

// Click to open the calendar
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    required property var barWindow

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        spacing: 8

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
            color: Theme.text
        }

        Text {
            text: "·"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.dim
        }

        Text {
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.dim
        }
    }

    CalendarPopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }
}
