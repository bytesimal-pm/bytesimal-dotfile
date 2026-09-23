import QtQuick
import Quickshell.Services.Pipewire

// Output device picker: click a device to make it the default sink
Column {
    id: list
    spacing: 2

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    Repeater {
        model: list.sinks

        Rectangle {
            id: device
            required property PwNode modelData
            readonly property bool current: modelData === Pipewire.defaultAudioSink

            width: list.width
            height: 30
            radius: 6
            color: current ? "#ffffff" : hover.containsMouse ? "#1affffff" : "transparent"

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: device.modelData.description || device.modelData.nickname || device.modelData.name
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: device.current
                color: device.current ? "#000000" : Theme.text
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Pipewire.preferredDefaultAudioSink = device.modelData
            }
        }
    }
}
