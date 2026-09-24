import QtQuick

// List row in popups (like DeviceList.qml): white when active
Rectangle {
    id: row
    property bool active: false
    property alias hovered: rowArea.containsMouse
    signal clicked(var mouse)
    default property alias content: rowContent.data

    height: 30
    radius: 6
    color: active ? "#ffffff" : hovered ? "#1affffff" : "transparent"

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => row.clicked(mouse)
    }

    Item {
        id: rowContent
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
    }
}
