import QtQuick

// Text button in popups: dim, bright on hover
Text {
    id: action
    signal clicked()

    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    elide: Text.ElideRight
    color: actionArea.containsMouse ? Theme.text : Theme.dim

    MouseArea {
        id: actionArea
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: action.clicked()
    }
}
