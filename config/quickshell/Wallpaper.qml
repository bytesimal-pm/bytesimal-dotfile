import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Video wallpaper with effects (shaders/wallpaper.frag): mouse parallax, vacuum into the
// spiral center (IPC only), glasses glint and a clock on an empty desktop,
// blur + dim behind windows, paused under a fullscreen window.
// The positions below are for shizuku-monochrome-4k.mp4 (uv = fraction of the 16:9 frame).
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor?.activeWorkspace ?? null
    readonly property bool hasWindows: (workspace?.toplevels?.values?.length ?? 0) > 0
    readonly property bool fullscreen: workspace?.hasFullscreen ?? false

    // Cursor position, -1..1 from the screen center, eased
    property real mouseX: 0
    property real mouseY: 0
    Behavior on mouseX { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on mouseY { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    // 0 = bare desktop, 1 = windows open (blur + dim)
    property real behind: hasWindows ? 1 : 0
    Behavior on behind { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    onFullscreenChanged: fullscreen ? video.pause() : video.play()

    // For Splash.qml: the shader loaded and is on screen / the video shows its first frame.
    // (A prebuilt .qsb never reports ShaderEffect.Compiled, only Uncompiled or Error.)
    readonly property bool shaderReady: fx.status !== ShaderEffect.Error && backingWindowVisible
    readonly property bool videoReady: video.position > 0

    SequentialAnimation {
        id: vacuumAnim
        NumberAnimation { target: fx; property: "vacuum"; to: 1; duration: 350; easing.type: Easing.InCubic }
        NumberAnimation { target: fx; property: "vacuum"; to: 0; duration: 1000; easing.type: Easing.OutElastic; easing.amplitude: 1; easing.period: 0.45 }
    }

    NumberAnimation {
        id: glintAnim
        target: fx; property: "glint"; from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine
    }
    Timer {
        interval: 6000 + Math.random() * 6000
        repeat: true
        running: !root.fullscreen && !root.hasWindows
        onTriggered: {
            interval = 6000 + Math.random() * 6000;
            glintAnim.restart();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function vacuum(): void { vacuumAnim.restart(); }
        function glint(): void { glintAnim.restart(); }
    }

    // What the shader distorts: the video and the clock
    Item {
        id: scene
        anchors.fill: parent

        Video {
            id: video
            anchors.fill: parent
            source: "file://" + Theme.wallpaper
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
            fillMode: VideoOutput.PreserveAspectCrop
        }

        // Clock on the empty left side, only on a bare desktop
        Column {
            x: parent.width * 0.07
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: parent.height * 0.12
            spacing: 0
            opacity: 1 - root.behind
            visible: opacity > 0

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 1
                shadowOpacity: 1
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: Theme.font
                font.pixelSize: root.height * 0.13
                font.weight: Font.Light
                color: Theme.text
            }
            Text {
                leftPadding: root.height * 0.008
                text: Qt.formatDateTime(clock.date, "dddd  d MMMM").toUpperCase()
                font.family: Theme.font
                font.pixelSize: root.height * 0.018
                font.letterSpacing: root.height * 0.006
                color: Theme.dim
            }
        }
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent

        // Depth mask for the parallax: white = Shizuku. Made from the video: her outline has a
        // red/cyan fringe the grey spiral doesn't, filled in from the background side.
        property var depth: Image {
            source: "assets/shizuku-depth.png"
            smooth: true
            visible: false
        }
        property var source: ShaderEffectSource {
            sourceItem: scene
            hideSource: true
            smooth: true
        }

        property vector2d mouse: Qt.vector2d(root.mouseX, root.mouseY)
        property vector2d center: Qt.vector2d(0.61, 0.33)
        property vector4d lensA: Qt.vector4d(0.792, 0.365, 0.031, 0.037)
        property vector4d lensB: Qt.vector4d(0.867, 0.339, 0.034, 0.041)
        property real aspect: width / Math.max(1, height)
        property real zoom: 1.04
        property real bgShift: 0.005
        property real fgShift: 0.007
        property real vacuum: 0
        property real glint: 0
        property real dim: root.behind * 0.35

        fragmentShader: Qt.resolvedUrl("shaders/wallpaper.frag.qsb")

        layer.enabled: root.behind > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.behind * 0.7
            blurMax: 48
        }
    }

    // Parallax follows the cursor over the bare desktop (with windows open it's blurred anyway)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: !root.fullscreen
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => {
            root.mouseX = mouse.x / width * 2 - 1;
            root.mouseY = mouse.y / height * 2 - 1;
        }
    }
}
