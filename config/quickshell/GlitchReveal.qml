import QtQuick

// Glitch in/out for a popup or panel, same look as the window glitch
// (shaders/windowglitch.frag): static that tears away on open, and on close covers the
// content and collapses like a CRT. Put it last in the panel (on top) and fill it.
// `content` is hidden during the close; `closed` fires when the close is done.
Item {
    id: fx

    property Item content: null
    property real radius: Theme.radius
    property int openDuration: 280
    property int closeDuration: 220

    signal closed()

    property real progress: 1
    property int mode: 0    // 0 = open, 1 = close
    readonly property bool running: anim.running

    function open(): void {
        mode = 0;
        if (content)
            content.opacity = 1;
        shader.seed = Math.random() * 100;
        anim.duration = openDuration;
        anim.restart();
    }

    function close(): void {
        if (anim.running && mode === 1)
            return;
        mode = 1;
        if (content)
            content.opacity = 0;
        shader.seed = Math.random() * 100;
        anim.duration = closeDuration;
        anim.restart();
    }

    NumberAnimation {
        id: anim
        target: fx
        property: "progress"
        from: 0
        to: 1
        onFinished: {
            if (fx.mode === 1) {
                fx.closed();
                if (fx.content)
                    fx.content.opacity = 1;
            }
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        visible: anim.running

        property real time: fx.progress * anim.duration / 1000
        property real progress: fx.progress
        property real mode: fx.mode
        property real seed: 0
        property vector2d size: Qt.vector2d(width, height)
        property real radius: fx.radius
        // Drag-only uniforms
        property real strength: 0
        property vector2d dir: Qt.vector2d(0, 0)
        property real margin: 0

        fragmentShader: Qt.resolvedUrl("shaders/windowglitch.frag.qsb")
    }
}
