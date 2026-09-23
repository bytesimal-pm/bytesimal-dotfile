import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    required property var barWindow

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted
    readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0

    // Keeps the sink's volume/mute properties live
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        id: icon
        text: Theme.speakerIcon(root.muted, root.percent)
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 2
        color: root.muted ? Theme.dim : Theme.text
    }

    VolumePopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
    }

    // Left: open the volume panel, right: mute, scroll: volume
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                popup.toggle();
            else if (root.ready)
                root.sink.audio.muted = !root.sink.audio.muted;
        }

        onWheel: wheel => {
            if (!root.ready) return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
