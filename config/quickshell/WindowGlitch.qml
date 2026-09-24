import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Window open/close effect (shaders/windowglitch.frag): black & white static over the
// window's rect that tears away on open, or covers it and collapses like a CRT on close,
// with a decoding "> EXEC kitty" / "> KILL firefox" label. Click-through overlay, mapped
// only while an effect plays. Dragging a window (Super + left mouse) gets a small version:
// Hyprland has no drag event, so hyprland.lua has extra press/release binds calling IPC.
// No screen grab: the live window shows through the torn gaps.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: effects.count > 0 || drag.active
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-glitch"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var monitor: Hyprland.monitorFor(screen)

    // address ("0x...") -> { x, y, w, h, monitor, workspace, cls }, from `hyprctl clients -j`.
    // A closed window is already gone from hyprctl, so close uses what was cached before.
    property var windows: ({})
    // Addresses of opened windows waiting for the next refresh to know their rect
    property var pendingOpens: []
    property bool refreshAgain: false
    property int nextKey: 0

    function refresh(): void {
        if (clients.running)
            refreshAgain = true;
        else
            clients.running = true;
    }

    // Adds an effect if the window is on this screen's active workspace
    function play(mode: string, win: var): void {
        if (!win || !monitor || win.monitor !== monitor.id)
            return;
        if (win.workspace !== (monitor.activeWorkspace?.id ?? -1))
            return;
        const mx = monitor.lastIpcObject?.x ?? 0;
        const my = monitor.lastIpcObject?.y ?? 0;
        effects.append({
            key: nextKey++,
            mode: mode,
            rx: win.x - mx,
            ry: win.y - my,
            rw: win.w,
            rh: win.h,
            label: (mode === "open" ? "> EXEC " : "> KILL ") + (win.cls || "process")
        });
    }

    function finish(key: int): void {
        for (let i = 0; i < effects.count; i++) {
            if (effects.get(i).key === key) {
                effects.remove(i);
                return;
            }
        }
    }

    Process {
        id: clients
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {};
                    for (const c of JSON.parse(text)) {
                        map[c.address] = {
                            x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1],
                            monitor: c.monitor, workspace: c.workspace.id, cls: c.class,
                            floating: c.floating
                        };
                    }
                    root.windows = map;
                } catch (e) {
                    return;
                }
                const opens = root.pendingOpens;
                root.pendingOpens = [];
                for (const addr of opens)
                    root.play("open", root.windows[addr]);
            }
        }
        onExited: {
            if (root.refreshAgain) {
                root.refreshAgain = false;
                running = true;
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event.name;
            if (name === "openwindow") {
                root.pendingOpens = root.pendingOpens.concat(["0x" + event.data.split(",")[0]]);
                root.refresh();
            } else if (name === "closewindow") {
                const addr = "0x" + event.data;
                root.play("close", root.windows[addr]);
                delete root.windows[addr];
            } else if (name === "movewindowv2" || name === "changefloatingmode" || name === "fullscreen"
                       || name === "activewindowv2" || name === "workspacev2") {
                root.refresh();
            }
        }
    }

    // For testing: plays on every window of the active workspace (nothing opens or closes)
    function playAll(mode: string): void {
        for (const addr in windows)
            play(mode, windows[addr]);
    }

    IpcHandler {
        target: "windowglitch"
        function open(): void { root.playAll("open"); }
        function close(): void { root.playAll("close"); }
        function dragStart(): void { drag.start(); }
        function dragEnd(): void { drag.stop(); }
    }

    // Drag: the window under the cursor at the start, then moved by the cursor delta
    // (works the same for floating and tiled windows)
    QtObject {
        id: drag

        property bool dragging: false
        readonly property bool active: dragging || burst.running
        property var win: null
        property real startX: 0
        property real startY: 0
        property real curX: 0
        property real curY: 0
        property real lastX: 0
        property real lastY: 0
        property real dirX: 1
        property real dirY: 0
        property real speed: 0     // 0..1, eased
        property real bump: 0      // pickup/drop burst

        function start(): void {
            win = null;
            dragging = true;
            cursor.first = true;
            cursor.running = true;
            giveUp.restart();
        }

        function stop(): void {
            if (!dragging)
                return;
            dragging = false;
            poll.stop();
            giveUp.stop();
            if (win)
                burst.restart();
        }

        // First cursor position: pick the window under it (floating ones are on top)
        function begin(x: real, y: real): void {
            const mx = root.monitor?.lastIpcObject?.x ?? 0;
            const my = root.monitor?.lastIpcObject?.y ?? 0;
            const ws = root.monitor?.activeWorkspace?.id ?? -1;
            let found = null;
            for (const addr in root.windows) {
                const w = root.windows[addr];
                if (w.monitor !== root.monitor?.id || w.workspace !== ws)
                    continue;
                if (x < w.x || y < w.y || x > w.x + w.w || y > w.y + w.h)
                    continue;
                if (!found || (w.floating && !found.floating))
                    found = w;
            }
            if (!found) {
                dragging = false;
                return;
            }
            win = { x: found.x - mx, y: found.y - my, w: found.w, h: found.h };
            startX = lastX = curX = x;
            startY = lastY = curY = y;
            speed = 0;
            burst.restart();
            poll.start();
        }

        function moved(x: real, y: real): void {
            const dx = x - lastX;
            const dy = y - lastY;
            const d = Math.sqrt(dx * dx + dy * dy);
            if (d > 0.5) {
                dirX = dx / d;
                dirY = dy / d;
            }
            speed = speed * 0.6 + Math.min(1, d / 80) * 0.4;
            lastX = curX = x;
            lastY = curY = y;
        }
    }

    Process {
        id: cursor
        property bool first: false
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p;
                try { p = JSON.parse(text); } catch (e) { return; }
                if (cursor.first) {
                    cursor.first = false;
                    drag.begin(p.x, p.y);
                } else if (drag.dragging) {
                    drag.moved(p.x, p.y);
                }
            }
        }
    }

    Timer {
        id: poll
        interval: 33
        repeat: true
        onTriggered: if (!cursor.running) cursor.running = true
    }

    // The release bind never came (released somewhere Hyprland didn't see): stop anyway
    Timer {
        id: giveUp
        interval: 30000
        onTriggered: drag.stop()
    }

    SequentialAnimation {
        id: burst
        NumberAnimation { target: drag; property: "bump"; from: 0.6; to: 0; duration: 150 }
    }

    ListModel {
        id: effects
    }

    Item {
        readonly property int margin: 40
        visible: drag.active && drag.win !== null
        x: (drag.win?.x ?? 0) + drag.curX - drag.startX - margin
        y: (drag.win?.y ?? 0) + drag.curY - drag.startY - margin
        width: (drag.win?.w ?? 0) + 2 * margin
        height: (drag.win?.h ?? 0) + 2 * margin

        ShaderEffect {
            anchors.fill: parent

            property real time: dragClock.elapsed
            property real progress: 0
            property real mode: 2
            property real seed: 0
            property vector2d size: Qt.vector2d(width, height)
            property real radius: 0
            property real strength: Math.max(drag.bump, drag.dragging ? Math.min(0.5, drag.speed) : 0)
            property vector2d dir: Qt.vector2d(drag.dirX, drag.dirY)
            property real margin: parent.margin

            fragmentShader: Qt.resolvedUrl("shaders/windowglitch.frag.qsb")
        }

        // Seconds since the drag started, for the shader's jumps
        QtObject {
            id: dragClock
            property real elapsed: 0
        }
        Timer {
            interval: 16
            repeat: true
            running: drag.active
            onTriggered: dragClock.elapsed += 0.016
        }
    }

    Repeater {
        model: effects

        Item {
            id: fxItem
            required property int key
            required property string mode
            required property real rx
            required property real ry
            required property real rw
            required property real rh
            required property string label

            x: rx
            y: ry
            width: rw
            height: rh

            readonly property int duration: mode === "open" ? 450 : 350
            property real progress: 0
            property int tick: 0

            NumberAnimation on progress {
                from: 0
                to: 1
                duration: fxItem.duration
                onFinished: root.finish(fxItem.key)
            }

            Timer {
                interval: 30
                repeat: true
                running: true
                onTriggered: fxItem.tick++
            }

            ShaderEffect {
                anchors.fill: parent

                property real time: fxItem.progress * fxItem.duration / 1000
                property real progress: fxItem.progress
                property real mode: fxItem.mode === "open" ? 0 : 1
                property real seed: Math.random() * 100
                property vector2d size: Qt.vector2d(width, height)
                property real radius: Theme.radius
                // Drag-only uniforms
                property real strength: 0
                property vector2d dir: Qt.vector2d(0, 0)
                property real margin: 0

                fragmentShader: Qt.resolvedUrl("shaders/windowglitch.frag.qsb")
            }

            // Decoding label in the top-left corner
            Rectangle {
                x: 10
                y: 10
                visible: fxItem.width > 160 && fxItem.height > 60
                width: labelText.implicitWidth + 12
                height: labelText.implicitHeight + 6
                color: "black"
                // Gone with the cover on open, before the collapse on close
                opacity: fxItem.mode === "open" ? 1 - Math.max(0, (fxItem.progress - 0.6) / 0.3)
                                                : 1 - Math.max(0, (fxItem.progress - 0.3) / 0.1)

                Text {
                    id: labelText
                    anchors.centerIn: parent

                    readonly property string glyphs: "!<>-_\\/[]{}=+*^?#01"
                    readonly property int revealed: Math.floor(Math.min(1, fxItem.progress / 0.35) * fxItem.label.length)

                    text: {
                        fxItem.tick; // re-scramble every tick
                        let out = fxItem.label.slice(0, revealed);
                        for (let i = revealed; i < fxItem.label.length; i++)
                            out += fxItem.label[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)];
                        return out + (fxItem.tick % 4 < 2 ? "█" : " ");
                    }
                    color: "white"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 1
                }
            }
        }
    }
}
