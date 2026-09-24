import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Workspace switch effect: grabs one frame of the new workspace, shows it glitched in
// black & white (shaders/glitch.frag) with "hacker" text decoding in the middle, then fades
// out to the real desktop. Click-through overlay, hidden between switches.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-glitch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int duration: 450
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor?.activeWorkspace ?? null

    // 0..1 over the whole effect
    property real progress: 1
    // Random 0.6..1, re-rolled every tick so the strength flickers
    property real flicker: 1
    property int tick: 0
    property string message: ""

    // Full glitch for the first 55 %, then it dies down while the whole thing fades
    readonly property real fadeStart: 0.55
    readonly property real fade: Math.max(0, (progress - fadeStart) / (1 - fadeStart))

    property var lastWorkspace: null
    onWorkspaceChanged: {
        const prev = lastWorkspace;
        lastWorkspace = workspace;
        // Skip the first value at startup and special workspaces (scratchpads)
        if (prev && workspace && workspace.id > 0)
            play();
    }

    function play(): void {
        const id = workspace?.id ?? 0;
        message = "> WORKSPACE " + String(id).padStart(2, "0") + " // ACCESS GRANTED";
        fx.seed = Math.random() * 100;
        if (anim.running || waiting.running) {
            // Already on screen: a new capture would include this overlay, reuse the frame
            if (anim.running)
                anim.restart();
            return;
        }
        // Map the (still empty, transparent) overlay first: the capture only comes in once
        // the window is up. A fresh ScreencopyView each time, so hasContent tells when it's in.
        root.visible = true;
        captureLoader.active = false;
        captureLoader.active = true;
        waiting.restart();
    }

    function start(): void {
        waiting.stop();
        anim.restart();
    }

    // No capture after this long: play on static instead
    Timer {
        id: waiting
        interval: 150
        onTriggered: root.start()
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.duration
        onFinished: {
            root.visible = false;
            captureLoader.active = false;
        }
    }

    Timer {
        interval: 30
        repeat: true
        running: anim.running
        onTriggered: {
            root.tick++;
            root.flicker = 0.6 + Math.random() * 0.4;
        }
    }

    IpcHandler {
        target: "glitch"
        function play(): void { root.play(); }
    }

    // The capture itself sits under the shader; before the effect starts it looks exactly
    // like the screen, so it doesn't matter that it shows
    Loader {
        id: captureLoader
        anchors.fill: parent
        active: false
        sourceComponent: ScreencopyView {
            captureSource: root.screen
            live: false
            onHasContentChanged: if (hasContent && waiting.running) root.start()
        }
    }

    Item {
        anchors.fill: parent
        visible: anim.running
        opacity: 1 - root.fade * root.fade

        ShaderEffect {
            id: fx
            anchors.fill: parent

            // ScreencopyView isn't a texture provider itself
            property var source: ShaderEffectSource {
                sourceItem: captureLoader.item
                hideSource: true
            }
            property real time: root.progress * root.duration / 1000
            property real strength: root.flicker * (1 - root.fade)
            property real seed: 0
            property real hasFrame: captureLoader.item?.hasContent ? 1 : 0

            fragmentShader: Qt.resolvedUrl("shaders/glitch.frag.qsb")
        }

        Text {
            id: label
            anchors.centerIn: parent
            // Jitters sideways while the glitch is strong
            anchors.horizontalCenterOffset: (root.tick % 3 - 1) * 6 * fx.strength * (root.tick % 2)

            readonly property string glyphs: "!<>-_\\/[]{}=+*^?#01"
            // Letters lock in left to right over the first 60 %
            readonly property int revealed: Math.floor(Math.min(1, root.progress / 0.6) * root.message.length)

            text: {
                root.tick; // re-scramble every tick
                let out = root.message.slice(0, revealed);
                for (let i = revealed; i < root.message.length; i++)
                    out += root.message[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)];
                return out + (root.tick % 4 < 2 ? " █" : "  ");
            }
            color: "white"
            style: Text.Outline
            styleColor: "black"
            font.family: Theme.font
            font.pixelSize: Math.round(root.height * 0.028)
            font.bold: true
            font.letterSpacing: 2
        }
    }
}
