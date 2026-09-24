import QtQuick

// On/off pill in popup headers
Rectangle {
    id: toggle
    property bool on: false
    signal toggled()

    width: 30
    height: 16
    radius: 8
    color: on ? "#ffffff" : "transparent"
    border.color: on ? "#ffffff" : Theme.dim
    border.width: 1

    Rectangle {
        width: 10
        height: 10
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        x: toggle.on ? toggle.width - width - 3 : 3
        color: toggle.on ? "#000000" : Theme.dim
        Behavior on x { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
