import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

// "Hacker" boot screen after login: covers the desktop while it loads. ASCII logo, a log
// whose [ WAIT ] lines turn [  OK  ] when the thing really is up (wallpaper shader and video,
// bar, Hyprland, PipeWire, network, BlueZ, battery), a progress bar, a hex column, CRT
// scanlines. Then ACCESS GRANTED and it tears away with the workspace glitch shader.
// Once per qs start (PersistentProperties survives hot reloads). Replay: qs ipc call splash play
PanelWindow {
    id: root

    required property var wallpaper
    required property var bar

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

    readonly property int minTime: 1400      // ms, so it reads even when everything is instant
    readonly property int maxTime: 4000      // ms, anything still waiting is skipped
    readonly property int optionalTime: 1200 // ms after its line shows, for things a PC may not have
    readonly property int exitDuration: 500

    readonly property string glyphs: "!<>-_\\/[]{}=+*^?#01"
    readonly property int px: Math.max(11, Math.round(height * 0.0135))

    PersistentProperties {
        id: persist
        reloadableId: "splash"
        property bool done: false
        // Deferred: showing the window during the reload pass crashes qs
        onLoaded: if (!done) Qt.callLater(root.play)
    }

    IpcHandler {
        target: "splash"
        function play(): void { root.play(); }
    }

    FileView { id: hostFile; path: "/proc/sys/kernel/hostname" }
    FileView { id: kernelFile; path: "/proc/sys/kernel/osrelease" }

    // ---------------------------------------------------------------- state

    property int tick: 0
    property real flicker: 1
    property int shown: 0          // rows revealed so far
    property var rows: []          // { kind, body, at (reveal time), check, status, ts }
    property real t0: 0
    property real progress: 0      // eased
    property string phase: "boot"  // boot → granted → exit
    property real grantedAt: 0
    property real exitProgress: 0  // 0..1 during the exit
    property var hexRows: []

    // Block letters, 5 rows, "#" = filled
    readonly property var font5: ({
        B: ["####.", "#...#", "####.", "#...#", "####."],
        Y: ["#...#", ".#.#.", "..#..", "..#..", "..#.."],
        T: ["#####", "..#..", "..#..", "..#..", "..#.."],
        E: ["#####", "#....", "####.", "#....", "#####"],
        S: [".####", "#....", ".###.", "....#", "####."],
        I: ["#####", "..#..", "..#..", "..#..", "#####"],
        M: ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
        A: [".###.", "#...#", "#####", "#...#", "#...#"],
        L: ["#....", "#....", "#....", "#....", "#####"]
    })

    function logoRows(word: string): var {
        const out = [];
        for (let r = 0; r < 5; r++) {
            let line = "";
            for (const ch of word)
                line += font5[ch][r].replace(/#/g, "██").replace(/\./g, "  ") + "  ";
            out.push(line);
        }
        return out;
    }

    function hexLine(): string {
        let s = "0x" + Math.floor(Math.random() * 0xffffffff).toString(16).padStart(8, "0") + "  ";
        for (let i = 0; i < 8; i++)
            s += Math.floor(Math.random() * 256).toString(16).padStart(2, "0") + " ";
        return s;
    }

    function hexDump(): string {
        let bytes = "", ascii = "";
        for (let i = 0; i < 8; i++) {
            const b = Math.floor(Math.random() * 256);
            bytes += b.toString(16).padStart(2, "0") + " ";
            ascii += b > 32 && b < 127 ? String.fromCharCode(b) : ".";
        }
        return "  0x7f4c" + Math.floor(Math.random() * 0xffff).toString(16).padStart(4, "0") + "  " + bytes + " " + ascii;
    }

    function sinkCount(): int {
        return Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio).length;
    }

    // Each check returns the target text once ready, or "" while waiting
    readonly property var checks: ({
        hypr: () => Hyprland.focusedMonitor ? "hyprland ipc :: " + Hyprland.focusedMonitor.name : "",
        display: () => (screen?.name ?? "?") + " " + (screen?.width ?? 0) + "x" + (screen?.height ?? 0),
        shader: () => wallpaper?.shaderReady ? "shaders/wallpaper.frag.qsb" : "",
        video: () => wallpaper?.videoReady ? Theme.wallpaper.split("/").pop() : "",
        bar: () => bar?.backingWindowVisible ? "quickshell bar" : "",
        audio: () => Pipewire.defaultAudioSink ? "pipewire :: " + sinkCount() + " sinks" : "",
        network: () => {
            const d = Networking.devices.values;
            return d.length > 0 ? "network :: " + d.map(x => x.name).join(" ") : "";
        },
        bluez: () => Bluetooth.defaultAdapter ? "bluez :: " + Bluetooth.defaultAdapter.adapterId : "",
        battery: () => {
            const dev = UPower.displayDevice;
            return dev?.ready && dev.isLaptopBattery ? "battery :: " + Math.round(dev.percentage * 100) + "%" : "";
        }
    })

    function play(): void {
        const r = [];
        for (const line of logoRows("BYTESIMAL"))
            r.push({ kind: "logo", body: line });
        r.push({ kind: "blank", body: " " });
        r.push({ kind: "header", body: "" });   // filled in when shown (files load async)
        r.push({ kind: "dim", body: "> establishing uplink..." });
        r.push({ kind: "blank", body: " " });
        const log = (verb, check, waitText, optional) =>
            r.push({ kind: "log", verb: verb, check: check, body: waitText, optional: optional, status: "WAIT" });
        log("link", "hypr", "hyprland ipc", false);
        log("probe", "display", "display", false);
        log("inject", "shader", "shaders/wallpaper.frag.qsb", false);
        r.push({ kind: "dim", body: hexDump() });
        log("decode", "video", Theme.wallpaper.split("/").pop(), false);
        log("mount", "bar", "quickshell bar", false);
        log("bind", "audio", "pipewire", true);
        r.push({ kind: "dim", body: hexDump() });
        log("scan", "network", "network", true);
        log("probe", "bluez", "bluez", true);
        log("probe", "battery", "battery", true);
        rows = r;
        shown = 0;
        progress = 0;
        phase = "boot";
        exitProgress = 0;
        t0 = Date.now();
        const hex = [];
        for (let i = 0; i < 60; i++)
            hex.push(hexLine());
        hexRows = hex;
        visible = true;
        ticker.restart();
    }

    function finish(): void {
        ticker.stop();
        visible = false;
        persist.done = true;
    }

    function update(): void {
        const now = Date.now();
        const elapsed = now - t0;
        tick++;
        flicker = 0.92 + Math.random() * 0.08;

        // Reveal the next row: logo rows quickly, the rest a bit slower
        if (shown < rows.length) {
            const last = shown > 0 ? rows[shown - 1].at : t0;
            const gap = shown > 0 && rows[shown - 1].kind === "logo" ? 45 : 70;
            if (now - last >= gap) {
                const row = rows[shown];
                row.at = now;
                row.ts = (elapsed / 1000).toFixed(3).padStart(6, " ");
                if (row.kind === "header") {
                    const user = Quickshell.env("USER") || "user";
                    const host = hostFile.text().trim() || "archlinux";
                    const kernel = kernelFile.text().trim();
                    row.body = "> BYTESIMAL//OS  —  " + user + "@" + host + (kernel ? "  ·  linux " + kernel : "");
                }
                shown++;
            }
        }

        // Poll the checks of the rows on screen
        let total = 0, doneCount = 0;
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            if (row.kind !== "log")
                continue;
            total++;
            if (row.status === "WAIT" && i < shown) {
                const target = checks[row.check]();
                if (target !== "") {
                    row.status = "OK";
                    row.body = target;
                } else if (elapsed > maxTime || (row.optional && now - row.at > optionalTime)) {
                    row.status = "SKIP";
                }
            }
            if (row.status !== "WAIT")
                doneCount++;
        }
        progress += ((total ? doneCount / total : 0) - progress) * 0.25;

        if (phase === "boot" && shown === rows.length && doneCount === total && elapsed >= minTime && progress > 0.97) {
            progress = 1;
            phase = "granted";
            grantedAt = now;
        } else if (phase === "granted" && now - grantedAt > 350) {
            phase = "exit";
            exitAnim.restart();
        }

        // Hex column scrolls up
        if (tick % 2 === 0) {
            const hex = hexRows.slice(1);
            hex.push(hexLine());
            hexRows = hex;
        }
    }

    Timer {
        id: ticker
        interval: 30
        repeat: true
        onTriggered: root.update()
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "exitProgress"
        from: 0
        to: 1
        duration: root.exitDuration
        onFinished: root.finish()
    }

    // Scrambles the part of `text` not typed in yet (for 160 ms after the row shows)
    function typed(text: string, at: real): string {
        const k = Math.floor(text.length * Math.min(1, (Date.now() - at) / 160));
        let out = text.slice(0, k);
        for (let i = k; i < text.length; i++)
            out += text[i] === " " ? " " : glyphs[Math.floor(Math.random() * glyphs.length)];
        return out;
    }

    function dots(text: string): string {
        const width = 44;
        return text.length >= width ? text.slice(0, width) : text + " " + ".".repeat(width - text.length - 1);
    }

    // ---------------------------------------------------------------- drawing

    Item {
        id: content
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Column {
            x: Math.round(root.width * 0.07)
            y: Math.round(root.height * 0.1)
            opacity: root.flicker

            Repeater {
                model: root.shown

                Row {
                    id: line
                    required property int index
                    readonly property var row: root.rows[index]
                    readonly property bool newest: index === root.shown - 1 && root.phase === "boot"
                    spacing: root.px
                    // Logo rows touch, so the block letters are solid
                    bottomPadding: line.row.kind === "logo" ? 0 : Math.round(root.px * 0.35)

                    // Timestamp
                    Text {
                        visible: line.row.kind === "log"
                        text: "[" + (line.row.ts ?? "") + " ]"
                        font.family: Theme.font
                        font.pixelSize: root.px
                        color: Theme.dim
                    }
                    Text {
                        text: {
                            root.tick; // re-scramble every tick
                            const r = line.row;
                            const body = r.kind === "log" ? r.verb.padEnd(7, " ") + root.dots(r.body) : r.body;
                            return root.typed(body, r.at) + (line.newest && root.tick % 16 < 8 ? " █" : "");
                        }
                        font.family: Theme.font
                        font.pixelSize: line.row.kind === "logo" ? Math.round(root.px * 0.62) : root.px
                        font.bold: line.row.kind === "header"
                        color: line.row.kind === "dim" ? Theme.dim : Theme.text
                    }
                    // [  OK  ] / [ WAIT ] / [ SKIP ]
                    Text {
                        visible: line.row.kind === "log"
                        text: {
                            root.tick;
                            const s = line.row.status;
                            return s === "OK" ? "[  OK  ]" : s === "SKIP" ? "[ SKIP ]"
                                : root.tick % 12 < 6 ? "[ WAIT ]" : "[      ]";
                        }
                        font.family: Theme.font
                        font.pixelSize: root.px
                        // Rows change in place: root.tick is the update signal
                        font.bold: root.tick >= 0 && line.row.status === "OK"
                        color: root.tick >= 0 && line.row.status === "OK" ? "#ffffff" : Theme.dim
                    }
                }
            }

            Item { width: 1; height: root.px }

            // Progress bar
            Text {
                visible: root.shown === root.rows.length && root.rows.length > 0
                text: {
                    const n = 32;
                    const full = Math.round(root.progress * n);
                    return "[" + "█".repeat(full) + "░".repeat(n - full) + "]  "
                        + String(Math.round(root.progress * 100)).padStart(3, " ") + "%  decrypting desktop";
                }
                font.family: Theme.font
                font.pixelSize: root.px
                color: Theme.text
            }

            Item { width: 1; height: root.px }

            Text {
                visible: root.phase !== "boot"
                text: {
                    root.tick;
                    return root.typed("> ACCESS GRANTED", root.grantedAt) + (root.tick % 8 < 4 ? " █" : "");
                }
                font.family: Theme.font
                font.pixelSize: Math.round(root.px * 1.6)
                font.bold: true
                font.letterSpacing: 2
                color: "#ffffff"
            }
        }

        // Hex column on the right
        Text {
            opacity: root.flicker
            anchors.right: parent.right
            anchors.rightMargin: Math.round(root.width * 0.03)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            text: root.hexRows.join("\n")
            font.family: Theme.font
            font.pixelSize: Math.round(root.px * 0.75)
            color: "#2e2e2e"
        }

        // CRT scanlines
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = "rgba(0, 0, 0, 0.35)";
                for (let y = 0; y < height; y += 3)
                    ctx.fillRect(0, y, width, 1);
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    // Exit: the splash itself through the workspace glitch shader, fading out
    ShaderEffect {
        anchors.fill: parent
        visible: root.phase === "exit"
        opacity: 1 - root.exitProgress * root.exitProgress

        property var source: ShaderEffectSource {
            sourceItem: content
            hideSource: root.phase === "exit"
        }
        property real time: root.exitProgress * root.exitDuration / 1000
        property real strength: (0.6 + (root.tick * 7 % 5) * 0.1) * (1 - root.exitProgress)
        property real seed: 7
        property real hasFrame: 1

        fragmentShader: Qt.resolvedUrl("shaders/glitch.frag.qsb")
    }
}
