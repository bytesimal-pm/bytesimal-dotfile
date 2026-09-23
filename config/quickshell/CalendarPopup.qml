import QtQuick
import Quickshell

// Month calendar under the bar clock. Weeks start on Monday.
BarPopup {
    id: cal
    popupWidth: 300

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Shown month (month is 0-11), reset to today on every open
    property int year: clock.date.getFullYear()
    property int month: clock.date.getMonth()
    onAboutToOpen: showToday()

    // Grid starts on the Monday on or before the 1st
    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property real cellWidth: Math.floor((popupWidth - 28) / 7)

    function showToday() {
        year = clock.date.getFullYear();
        month = clock.date.getMonth();
    }

    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    component NavButton: Text {
        id: nav
        signal clicked()
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 6
        color: navArea.containsMouse ? Theme.text : Theme.dim

        MouseArea {
            id: navArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    // Header: time + full date
    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm:ss")
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 18
        font.bold: true
        color: Theme.text
    }

    Text {
        topPadding: -8
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.dim
    }

    Separator { width: parent.width }

    // Month navigation
    Item {
        width: parent.width
        height: 26

        NavButton {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0141}" // chevron-left
            onClicked: cal.shift(-1)
        }

        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy")
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            color: titleArea.containsMouse ? "#ffffff" : Theme.text

            // Back to the current month
            MouseArea {
                id: titleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.showToday()
            }
        }

        NavButton {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0142}" // chevron-right
            onClicked: cal.shift(1)
        }
    }

    // Weekday names
    Row {
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            Text {
                required property string modelData
                width: cal.cellWidth
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
                color: Theme.dim
            }
        }
    }

    // Days. Scroll to change month.
    MouseArea {
        width: days.width
        height: days.height
        acceptedButtons: Qt.NoButton
        onWheel: wheel => cal.shift(wheel.angleDelta.y > 0 ? -1 : 1)

        Grid {
            id: days
            columns: 7

            Repeater {
                model: 42

                Rectangle {
                    id: cell
                    required property int index
                    readonly property date day: new Date(cal.year, cal.month, index - cal.offset + 1)
                    readonly property bool inMonth: day.getMonth() === cal.month
                    readonly property bool today: day.toDateString() === clock.date.toDateString()

                    width: cal.cellWidth
                    height: 30
                    radius: 6
                    color: today ? "#ffffff" : hover.containsMouse ? "#1affffff" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: cell.day.getDate()
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: cell.today
                        color: cell.today ? "#000000" : cell.inMonth ? Theme.text : "#3a3a3a"
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
