import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// App launcher. Toggle with: qs ipc call launcher toggle
PanelWindow {
    id: launcher

    visible: false
    screen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int maxRows: 8
    readonly property int rowHeight: 44
    property var results: []
    property int selected: 0

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible ? launcher.close() : launcher.open(); }
        function open(): void { launcher.open(); }
        function close(): void { launcher.close(); }
    }

    // The app list is scanned in the background: load it at startup and
    // refresh when it changes (new install, or the first scan finishing)
    Component.onCompleted: update()
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { launcher.update(); }
    }

    function open() {
        search.text = "";
        update();
        visible = true;
        search.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    function launch(entry) {
        if (!entry) return;
        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", ...entry.command]);
        else
            entry.execute();
        close();
    }

    function move(delta) {
        if (results.length === 0) return;
        selected = (selected + delta + results.length) % results.length;
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    // Lower score = better match; -1 = no match
    function score(entry, q) {
        const name = entry.name.toLowerCase();
        if (name.startsWith(q)) return 0;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 1;
        if (name.includes(q)) return 2;
        const extra = [entry.genericName, entry.comment, ...(entry.keywords ?? [])].join(" ").toLowerCase();
        if (extra.includes(q)) return 3;
        let i = 0;
        for (const c of name) if (c === q[i]) i++;
        return i === q.length ? 4 : -1;
    }

    function update() {
        const q = search.text.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const byName = (a, b) => a.name.localeCompare(b.name);

        if (q === "") {
            results = apps.sort(byName);
        } else {
            results = apps
                .map(e => ({ e, s: score(e, q) }))
                .filter(x => x.s >= 0)
                .sort((a, b) => a.s - b.s || byName(a.e, b.e))
                .map(x => x.e);
        }
        selected = 0;
        list.positionViewAtBeginning();
    }

    // Dim backdrop, click outside the box to close
    Rectangle {
        anchors.fill: parent
        color: "#66000000"

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
        }
    }

    Rectangle {
        id: box
        width: 560
        height: column.implicitHeight + 24
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        color: "#cc000000"
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        // Swallow clicks so they don't reach the backdrop
        MouseArea { anchors.fill: parent }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Search field
            Row {
                width: parent.width
                height: 32
                spacing: 10
                leftPadding: 6

                Text {
                    text: "❯"
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: search
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: "#ffffff"
                    selectionColor: "#ffffff"
                    selectedTextColor: "#000000"
                    cursorVisible: true
                    focus: true
                    onTextChanged: launcher.update()

                    Text {
                        visible: search.text === ""
                        text: "Search apps…"
                        font: search.font
                        color: Theme.dim
                    }

                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        if (event.key === Qt.Key_Escape) launcher.close();
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) launcher.launch(launcher.results[launcher.selected]);
                        else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J) || event.key === Qt.Key_Tab) launcher.move(1);
                        else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K) || event.key === Qt.Key_Backtab) launcher.move(-1);
                        else return;
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            ListView {
                id: list
                width: parent.width
                height: Math.min(launcher.results.length, launcher.maxRows) * launcher.rowHeight
                clip: true
                model: launcher.results
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool active: index === launcher.selected

                    width: list.width
                    height: launcher.rowHeight
                    radius: 6
                    color: active ? "#ffffff" : "transparent"

                    Item {
                        id: icon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26

                        // "" when the icon theme doesn't have it
                        readonly property string path: Quickshell.iconPath(row.modelData.icon, true)

                        Image {
                            anchors.fill: parent
                            visible: icon.path !== ""
                            source: icon.path
                            sourceSize.width: 26
                            sourceSize.height: 26
                            smooth: true
                        }

                        // Fallback: first letter of the app name
                        Rectangle {
                            anchors.fill: parent
                            visible: icon.path === ""
                            radius: 6
                            color: "transparent"
                            border.width: 1
                            border.color: row.active ? "#000000" : "#ffffff"

                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.name.charAt(0).toUpperCase()
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.bold: true
                                color: row.active ? "#000000" : "#ffffff"
                            }
                        }
                    }

                    Column {
                        anchors.left: icon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: row.active
                            color: row.active ? "#000000" : "#ffffff"
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: row.modelData.comment || row.modelData.genericName || ""
                            elide: Text.ElideRight
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: row.active ? "#4d4d4d" : Theme.dim
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: launcher.selected = row.index
                        onClicked: launcher.launch(row.modelData)
                    }
                }
            }

            Text {
                visible: launcher.results.length === 0
                text: "No apps found"
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.dim
                leftPadding: 6
            }
        }
    }
}
