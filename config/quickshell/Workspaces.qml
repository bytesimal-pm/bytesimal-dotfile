import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
    id: root
    spacing: 4

    readonly property int minShown: 5
    readonly property int maxIcons: 4
    readonly property int activeId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    // Always show 1..minShown, plus any higher workspace that exists
    readonly property int count: {
        let max = minShown;
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > max) max = ws.id;
        return max;
    }

    function workspace(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id) ?? null;
    }

    function switchTo(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // App ids of the workspace's windows, without duplicates
    function appsOn(ws) {
        if (!ws) return [];
        const ids = [];
        for (const t of ws.toplevels.values) {
            const id = t.wayland?.appId || t.lastIpcObject?.class || "";
            if (id !== "" && !ids.includes(id)) ids.push(id);
        }
        return ids;
    }

    // Icon path for an app id ("" if the icon theme doesn't have it).
    // Reads the desktop entry list so it updates once the entries are scanned.
    function iconFor(appId) {
        DesktopEntries.applications.values.length;
        const entry = DesktopEntries.heuristicLookup(appId);
        return Quickshell.iconPath(entry?.icon || appId, true);
    }

    Repeater {
        model: root.count

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.activeId
            readonly property var apps: root.appsOn(root.workspace(wsId))
            readonly property bool occupied: apps.length > 0

            width: Math.max(active ? 28 : 20, content.implicitWidth + (occupied ? 16 : 0))
            height: 22
            radius: 11
            color: active ? Theme.accent : "transparent"

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.wsId
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: pill.active
                    color: pill.active ? "#101014" : pill.occupied ? Theme.text : Theme.dim
                }

                Repeater {
                    model: pill.apps.slice(0, root.maxIcons)

                    Item {
                        id: app
                        required property string modelData
                        readonly property string path: root.iconFor(modelData)

                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14

                        Image {
                            anchors.fill: parent
                            visible: app.path !== ""
                            source: app.path
                            sourceSize.width: 28
                            sourceSize.height: 28
                            smooth: true
                        }

                        // Fallback: first letter of the app id
                        Text {
                            anchors.centerIn: parent
                            visible: app.path === ""
                            text: app.modelData.split(".").pop().charAt(0).toUpperCase()
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            font.bold: true
                            color: pill.active ? "#101014" : Theme.text
                        }
                    }
                }

                // More windows than icons shown
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.apps.length > root.maxIcons
                    text: `+${pill.apps.length - root.maxIcons}`
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    color: pill.active ? "#101014" : Theme.dim
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.switchTo(pill.wsId)
            }
        }
    }

    // Scroll anywhere on the workspaces to cycle through them
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const next = root.activeId + (event.angleDelta.y < 0 ? 1 : -1);
            if (next >= 1) root.switchTo(next);
        }
    }
}
