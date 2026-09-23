import QtQuick
import Quickshell.Services.Pipewire

// Mute button + slider + percent for a Pipewire node
Row {
    id: volRow
    required property PwNode node
    readonly property bool ready: node !== null && node.audio !== null
    readonly property bool muted: ready && node.audio.muted
    readonly property int percent: ready ? Math.round(node.audio.volume * 100) : 0

    // Speaker glyph by default; mic rows override it
    property string glyph: Theme.speakerIcon(muted, percent)

    spacing: 10

    Text {
        width: 20
        anchors.verticalCenter: parent.verticalCenter
        text: volRow.glyph
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 4
        color: volRow.muted ? Theme.dim : Theme.text

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (volRow.ready) volRow.node.audio.muted = !volRow.node.audio.muted
        }
    }

    VolumeSlider {
        node: volRow.node
        width: volRow.width - 20 - 40 - volRow.spacing * 2
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        width: 40
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: !volRow.ready ? "--" : volRow.muted ? "mute" : `${volRow.percent}%`
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: volRow.muted ? Theme.dim : Theme.text
    }
}
