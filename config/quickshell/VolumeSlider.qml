import QtQuick
import Quickshell.Services.Pipewire

// Volume slider for a Pipewire node: click/drag to set (unmutes), scroll for ±5%
Item {
    id: slider
    required property PwNode node
    readonly property bool ready: node !== null && node.audio !== null
    readonly property real value: ready ? Math.min(1, node.audio.volume) : 0
    readonly property bool muted: ready && node.audio.muted

    implicitHeight: 20

    function set(x) {
        if (!ready) return;
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, x / width));
    }

    Rectangle {
        width: parent.width
        height: 4
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.border

        Rectangle {
            width: parent.width * slider.value
            height: parent.height
            radius: parent.radius
            color: slider.muted ? Theme.dim : Theme.accent
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, parent.width * slider.value - width / 2))
        color: slider.muted ? Theme.dim : Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => slider.set(mouse.x)
        onPositionChanged: mouse => { if (pressed) slider.set(mouse.x); }
        onWheel: wheel => {
            if (!slider.ready) return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            slider.node.audio.volume = Math.max(0, Math.min(1, slider.node.audio.volume + step));
        }
    }
}
