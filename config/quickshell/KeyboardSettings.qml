pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Keyboard state (layouts, active layout) and the Keyboard Settings window.
// Open from the keyboard panel, or with: qs ipc call keyboard toggle
// Settings go to a Lua file that hyprland.lua reads; every change reloads the Hyprland config.
Singleton {
    id: kbd

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hypr/keyboard.lua"
    readonly property int maxLayouts: 4  // xkb limit

    // Applied layouts, from the main keyboard: [{ layout, variant }]
    property var layouts: [{ layout: "us", variant: "" }]
    property int activeIndex: 0

    // Everything else in the file. switch: "" (none), an xkb "grp:..." option
    // (modifier-only shortcuts) or "bind:<Hyprland key string>" (anything else)
    readonly property var defaults: ({ switch: "", switch_label: "", numlock: false })
    property var settings: defaults

    readonly property string activeCode: code(layouts[activeIndex]?.layout ?? "us")

    // xkb keycodes of the modifier keys
    readonly property var modKeys: ({
        37: "LCtrl", 105: "RCtrl", 50: "LShift", 62: "RShift",
        64: "LAlt", 108: "RAlt", 133: "LSuper", 134: "RSuper"
    })
    // Modifier-only shortcuts xkb can do (a Hyprland bind can't): sorted held keys → option
    readonly property var modOnly: ({
        "LAlt+LShift": "grp:alt_shift_toggle", "LAlt+RShift": "grp:alt_shift_toggle",
        "LShift+RAlt": "grp:alt_shift_toggle", "RAlt+RShift": "grp:alt_shift_toggle",
        "LCtrl+LShift": "grp:ctrl_shift_toggle", "LCtrl+RShift": "grp:ctrl_shift_toggle",
        "LShift+RCtrl": "grp:ctrl_shift_toggle", "RCtrl+RShift": "grp:ctrl_shift_toggle",
        "LAlt+LCtrl": "grp:ctrl_alt_toggle", "LAlt+RCtrl": "grp:ctrl_alt_toggle",
        "LCtrl+RAlt": "grp:ctrl_alt_toggle", "RAlt+RCtrl": "grp:ctrl_alt_toggle",
        "LCtrl+LSuper": "grp:lctrl_lwin_toggle",
        "LShift+RShift": "grp:shifts_toggle", "LAlt+RAlt": "grp:alts_toggle", "LCtrl+RCtrl": "grp:ctrls_toggle",
        "LAlt": "grp:lalt_toggle", "RAlt": "grp:toggle", "LCtrl": "grp:lctrl_toggle", "RCtrl": "grp:rctrl_toggle",
        "LShift": "grp:lshift_toggle", "RShift": "grp:rshift_toggle",
        "LSuper": "grp:lwin_toggle", "RSuper": "grp:rwin_toggle"
    })
    // Names of keys whose Qt text is empty or unhelpful, by xkb keycode
    readonly property var keyNames: ({
        9: "Esc", 22: "Backspace", 23: "Tab", 36: "Enter", 49: "`", 65: "Space", 66: "Caps Lock",
        67: "F1", 68: "F2", 69: "F3", 70: "F4", 71: "F5", 72: "F6", 73: "F7", 74: "F8", 75: "F9", 76: "F10",
        95: "F11", 96: "F12", 78: "Scroll Lock", 107: "Print", 110: "Home", 111: "Up", 112: "Page Up",
        113: "Left", 114: "Right", 115: "End", 116: "Down", 117: "Page Down", 118: "Insert", 119: "Delete",
        127: "Pause", 135: "Menu"
    })

    function prettyMods(held) {
        return held.map(k => k.startsWith("R") && held.length === 1 ? "Right " + k.slice(1) : k.slice(1))
            .filter((m, i, a) => a.indexOf(m) === i)
            .join(" + ");
    }

    function code(layout) {
        return layout === "us" ? "EN" : layout.toUpperCase();
    }

    function nameOf(l) {
        return names[l.layout + "(" + l.variant + ")"] ?? (l.variant !== "" ? `${l.layout} (${l.variant})` : l.layout);
    }

    function shortcutName() {
        if (settings.switch_label) return settings.switch_label;
        if (settings.switch === "grp:win_space_toggle") return "Super + Space";
        if (settings.switch === "grp:caps_toggle") return "Caps Lock";
        const combo = Object.keys(modOnly).find(k => modOnly[k] === settings.switch);
        return combo ? prettyMods(combo.split("+")) : settings.switch;
    }

    function refresh() { devices.running = true; }
    function switchTo(index) { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)]); }
    function next() { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); }

    // Write the settings file and reload Hyprland (which reads it)
    function save(list, patch) {
        layouts = list;
        activeIndex = 0;
        settings = Object.assign({}, settings, patch ?? {});
        const variants = list.some(l => l.variant !== "") ? list.map(l => l.variant).join(",") : "";
        const all = Object.assign({ layout: list.map(l => l.layout).join(","), variant: variants }, settings);
        const lua = "return {\n" + Object.keys(all).map(k => `    ${k} = ${JSON.stringify(all[k])},\n`).join("") + "}\n";
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1" && hyprctl reload config-only',
            "sh", stateFile, lua]);
    }
    function set(patch) { save(layouts, patch); }

    function move(i, delta) {
        const list = layouts.slice();
        const [l] = list.splice(i, 1);
        list.splice(i + delta, 0, l);
        save(list);
    }
    function remove(i) { save(layouts.filter((_, j) => j !== i)); }
    function add(e) { save(layouts.concat([{ layout: e.layout, variant: e.variant }])); }
    // From the search results. Runs here, not in the result row: closing the search
    // destroys that row, and a handler in a destroyed row can't reach `kbd` any more.
    function pick(e) {
        adding = false;
        add(e);
    }

    function open() {
        adding = false;
        scroll.contentY = 0;
        refresh();
        win.visible = true;
    }
    function close() {
        if (recording) stopRecording(false);
        win.visible = false;
    }
    function toggle() { win.visible ? close() : open(); }

    IpcHandler {
        target: "keyboard"
        function toggle(): void { kbd.toggle(); }
        function open(): void { kbd.open(); }
        function close(): void { kbd.close(); }
        function next(): void { kbd.next(); }
    }

    Process {
        id: devices
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main);
                    if (!kb) return;
                    const names = kb.layout.split(",");
                    const variants = kb.variant.split(",");
                    kbd.layouts = names.map((l, i) => ({ layout: l, variant: variants[i] ?? "" }));
                    kbd.activeIndex = Math.max(0, Math.min(names.length - 1, kb.active_layout_index ?? 0));
                } catch (e) {}
            }
        }
    }

    // The rest can't all be read back from Hyprland ("grave" is a bind), so read the file.
    // It's written by save() only: `key = <JSON value>,` per line.
    FileView {
        path: kbd.stateFile
        printErrors: false  // no file until the first save
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const s = Object.assign({}, kbd.defaults);
            const re = /(\w+)\s*=\s*("(?:[^"\\]|\\.)*"|true|false|-?[\d.]+)/g;
            let m;
            const src = text();
            while ((m = re.exec(src)) !== null) {
                if (m[1] in s) s[m[1]] = JSON.parse(m[2]);
            }
            kbd.settings = s;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                kbd.refresh();
        }
        function onFocusedWorkspaceChanged() { kbd.close(); }
    }

    // All xkb layouts and variants: [{ layout, variant, name }], sorted by name
    property var catalog: []
    readonly property var names: {
        const map = {};
        for (const e of catalog) map[e.layout + "(" + e.variant + ")"] = e.name;
        return map;
    }

    FileView {
        path: "/usr/share/X11/xkb/rules/evdev.lst"
        onLoaded: {
            const list = [];
            let section = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("! ")) {
                    section = line.slice(2).trim();
                    continue;
                }
                const m = line.match(/^\s+(\S+)\s+(.+)$/);
                if (!m) continue;
                if (section === "layout") {
                    list.push({ layout: m[1], variant: "", name: m[2] });
                } else if (section === "variant") {
                    // "  pat             th: Thai (Pattachote)"
                    const v = m[2].match(/^(\S+):\s*(.+)$/);
                    if (v) list.push({ layout: v[1], variant: m[1], name: v[2] });
                }
            }
            kbd.catalog = list.sort((a, b) => a.name.localeCompare(b.name));
        }
    }

    // ── Window ──

    property bool adding: false

    readonly property var results: {
        const q = search.text.trim().toLowerCase();
        const taken = layouts.map(l => l.layout + "(" + l.variant + ")");
        return catalog
            .filter(e => !taken.includes(e.layout + "(" + e.variant + ")"))
            .filter(e => q === "" || e.name.toLowerCase().includes(q) || e.layout === q)
            .slice(0, 60);
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.text
        elide: Text.ElideRight
    }

    component Link: Text {
        id: link
        signal clicked()
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: linkArea.containsMouse ? Theme.text : Theme.dim

        MouseArea {
            id: linkArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // ── Shortcut recorder ──

    property bool recording: false
    property var held: []       // modifier keys down right now
    property var chord: []      // most modifiers held at once in this press
    property var captured: null // { switch, switch_label } waiting for Save
    property string recordError: ""
    property var switchBefore: null

    // Start listening. The current shortcut is turned off first,
    // or Hyprland would take its keys before they reach the window.
    function startRecording() {
        recordError = "";
        captured = null;
        held = [];
        chord = [];
        switchBefore = { switch: settings.switch, switch_label: settings.switch_label };
        if (settings.switch !== "") set({ switch: "", switch_label: "" });
        recording = true;
        recorder.forceActiveFocus();
    }
    function stopRecording(keep) {
        recording = false;
        if (keep && captured) set(captured);
        else if (switchBefore && switchBefore.switch !== settings.switch) set(switchBefore);
        captured = null;
        switchBefore = null;
    }

    function keyPressed(event) {
        if (event.isAutoRepeat) return;
        const sc = event.nativeScanCode;
        const mod = modKeys[sc];
        if (mod) {
            if (!held.includes(mod)) held = held.concat([mod]);
            if (held.length >= chord.length) chord = held.slice();
            return;
        }
        if (sc === 9 && held.length === 0) { // Esc: cancel
            stopRecording(false);
            return;
        }
        recordError = "";
        chord = [];
        if (sc === 66 && held.length === 0) { // Caps Lock alone: xkb, a bind would still toggle caps
            captured = { switch: "grp:caps_toggle", switch_label: "Caps Lock" };
            return;
        }
        const mods = [];
        if (held.some(m => m.endsWith("Super"))) mods.push("SUPER");
        if (held.some(m => m.endsWith("Ctrl"))) mods.push("CTRL");
        if (held.some(m => m.endsWith("Alt"))) mods.push("ALT");
        if (held.some(m => m.endsWith("Shift"))) mods.push("SHIFT");
        const name = keyNames[sc] ?? (event.text.trim() !== "" ? event.text.toUpperCase() : "Key " + sc);
        // By keycode, so it's the same key in every layout
        captured = {
            switch: "bind:" + mods.concat(["code:" + sc]).join(" + "),
            switch_label: mods.map(m => m.charAt(0) + m.slice(1).toLowerCase()).concat([name]).join(" + ")
        };
    }

    function keyReleased(event) {
        if (event.isAutoRepeat) return;
        const mod = modKeys[event.nativeScanCode];
        if (!mod) return;
        held = held.filter(m => m !== mod);
        // All modifiers up and no other key pressed with them: a modifier-only shortcut
        if (held.length === 0 && chord.length > 0) {
            const combo = chord.slice().sort().join("+");
            chord = [];
            if (modOnly[combo]) {
                recordError = "";
                captured = { switch: modOnly[combo], switch_label: prettyMods(combo.split("+")) };
            } else {
                recordError = "Those keys can't switch layouts on their own, add a key";
            }
        }
    }

    FloatingWindow {
        id: win
        visible: false
        title: "Keyboard Settings"
        implicitWidth: 480
        implicitHeight: 460
        minimumSize: Qt.size(380, 360)
        color: "#cc000000"

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: kbd.adding ? kbd.adding = false : kbd.close()

            // Header
            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                height: 28

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f030c}  Keyboard Settings"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    color: Theme.text
                }

                Link {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f0156}" // close
                    font.pixelSize: Theme.fontSize + 6
                    onClicked: kbd.close()
                }
            }

            Separator {
                id: headerLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.topMargin: 12
            }

            Flickable {
                id: scroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerLine.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 18
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: scroll.width
                    spacing: 12

                    // ── Layouts ──

                    SectionLabel { text: "LAYOUTS  ·  the first one is used after login" }

                    Column {
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: kbd.layouts

                            ListRow {
                                id: row
                                required property var modelData
                                required property int index

                                width: parent.width
                                height: 30
                                active: index === kbd.activeIndex
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) kbd.switchTo(row.index);
                                }

                                Label {
                                    id: code
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26
                                    text: kbd.code(row.modelData.layout)
                                    font.bold: true
                                    color: row.active ? "#000000" : Theme.dim
                                }

                                Label {
                                    anchors.left: code.right
                                    anchors.right: actions.left
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: kbd.nameOf(row.modelData)
                                    font.bold: row.active
                                    color: row.active ? "#000000" : Theme.text
                                }

                                Row {
                                    id: actions
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 14

                                    TextButton {
                                        visible: row.index > 0
                                        text: "\u{f005d}" // move up
                                        onClicked: kbd.move(row.index, -1)
                                    }
                                    TextButton {
                                        visible: kbd.layouts.length > 1
                                        text: "\u{f0156}" // remove
                                        onClicked: kbd.remove(row.index)
                                    }
                                }
                            }
                        }
                    }

                    TextButton {
                        visible: !kbd.adding && kbd.layouts.length < kbd.maxLayouts
                        leftPadding: 10
                        text: "\u{f0415}  Add layout"
                        onClicked: {
                            search.text = "";
                            kbd.adding = true;
                            search.forceActiveFocus();
                        }
                    }

                    // Add: search + results
                    Rectangle {
                        visible: kbd.adding
                        width: parent.width
                        height: 30
                        radius: 6
                        color: "transparent"
                        border.color: search.activeFocus ? Theme.text : Theme.border
                        border.width: 1

                        TextInput {
                            id: search
                            anchors.left: parent.left
                            anchors.right: cancel.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.text
                            selectionColor: "#ffffff"
                            selectedTextColor: "#000000"
                            onAccepted: if (kbd.results.length > 0) kbd.pick(kbd.results[0])
                            Keys.onEscapePressed: kbd.adding = false

                            Label {
                                visible: search.text === ""
                                text: "Search layouts (Thai, German, de, …)"
                                color: Theme.dim
                            }
                        }

                        TextButton {
                            id: cancel
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{f0156}"
                            onClicked: kbd.adding = false
                        }
                    }

                    Flickable {
                        id: resultList
                        visible: kbd.adding && kbd.results.length > 0
                        width: parent.width
                        height: Math.min(contentHeight, 8 * 32)
                        contentHeight: resultRows.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: resultRows
                            width: resultList.width
                            spacing: 2

                            Repeater {
                                model: kbd.adding ? kbd.results : []

                                ListRow {
                                    id: result
                                    required property var modelData
                                    width: parent.width
                                    height: 30
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.LeftButton) kbd.pick(result.modelData);
                                    }

                                    Label {
                                        anchors.left: parent.left
                                        anchors.right: resultCode.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: result.modelData.name
                                    }

                                    Label {
                                        id: resultCode
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: Theme.fontSize - 1
                                        color: Theme.dim
                                        text: result.modelData.layout + (result.modelData.variant !== "" ? "(" + result.modelData.variant + ")" : "")
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        visible: kbd.adding && kbd.results.length === 0
                        leftPadding: 10
                        color: Theme.dim
                        text: "No match"
                    }

                    Separator { width: parent.width }

                    // ── Keys ──

                    SectionLabel { text: "SWITCH LAYOUT WITH" }

                    // Waits for a key press while recording
                    Rectangle {
                        id: recorder
                        width: parent.width
                        height: 30
                        radius: 6
                        color: kbd.recording ? "#1affffff" : "transparent"
                        border.color: kbd.recording ? Theme.text : Theme.border
                        border.width: 1

                        Keys.onPressed: event => {
                            event.accepted = true;
                            if (kbd.recording) kbd.keyPressed(event);
                        }
                        Keys.onReleased: event => {
                            event.accepted = true;
                            if (kbd.recording) kbd.keyReleased(event);
                        }
                        onActiveFocusChanged: if (!activeFocus && kbd.recording) kbd.stopRecording(false)

                        Label {
                            anchors.left: parent.left
                            anchors.right: recActions.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            font.bold: kbd.recording ? kbd.captured !== null || kbd.held.length > 0 : kbd.settings.switch !== ""
                            color: kbd.recording && kbd.captured === null && kbd.held.length === 0 || !kbd.recording && kbd.settings.switch === "" ? Theme.dim : Theme.text
                            text: !kbd.recording ? (kbd.settings.switch !== "" ? kbd.shortcutName() : "None")
                                : kbd.captured ? kbd.captured.switch_label
                                : kbd.held.length > 0 ? kbd.prettyMods(kbd.held.slice().sort()) + " + …"
                                : "Press the keys…  (Esc cancels)"
                        }

                        Row {
                            id: recActions
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            TextButton {
                                visible: !kbd.recording
                                text: kbd.settings.switch !== "" ? "Change" : "Set"
                                onClicked: kbd.startRecording()
                            }
                            TextButton {
                                visible: !kbd.recording && kbd.settings.switch !== ""
                                text: "Clear"
                                onClicked: kbd.set({ switch: "", switch_label: "" })
                            }
                            TextButton {
                                visible: kbd.recording && kbd.captured !== null
                                text: "Save"
                                color: Theme.text
                                font.bold: true
                                onClicked: kbd.stopRecording(true)
                            }
                            TextButton {
                                visible: kbd.recording
                                text: "Cancel"
                                onClicked: kbd.stopRecording(false)
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.dim
                        text: kbd.recordError !== "" ? "\u{f0026}  " + kbd.recordError
                            : kbd.recording && kbd.captured !== null ? "Press other keys to try again, or Save"
                            : kbd.recording ? "Modifiers alone work too (Alt + Shift, Right Alt…). Keys used by other shortcuts can't be recorded."
                            : "Right-click the bar icon also switches."
                    }

                    Separator { width: parent.width }

                    Item {
                        width: parent.width
                        height: 20

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Num Lock on at login"
                        }
                        Switch {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: kbd.settings.numlock
                            onToggled: kbd.set({ numlock: !kbd.settings.numlock })
                        }
                    }

                    // Try the layouts here
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: "transparent"
                        border.color: test.activeFocus ? Theme.text : Theme.border
                        border.width: 1

                        TextInput {
                            id: test
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.text
                            selectionColor: "#ffffff"
                            selectedTextColor: "#000000"

                            Label {
                                visible: test.text === ""
                                text: "Type here to test"
                                color: Theme.dim
                            }
                        }
                    }
                }
            }
        }
    }
}
