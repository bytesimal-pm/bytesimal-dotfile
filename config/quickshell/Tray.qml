import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Tray icons. Left click: activate, right click: menu (TrayMenu.qml),
// middle click: secondary action, scroll: scroll.
// Drag an icon sideways to reorder; the order is saved across restarts.
Item {
    id: root

    required property var barWindow

    readonly property int slot: 22
    readonly property int gap: 4
    implicitWidth: row.implicitWidth
    implicitHeight: slot

    // Saved order of tray item ids (apps not running now keep their place)
    property var order: []

    readonly property var items: {
        const rank = id => {
            const i = order.indexOf(id);
            return i < 0 ? order.length : i;
        };
        return SystemTray.items.values
            .map((item, i) => ({ item, i }))
            .sort((a, b) => rank(a.item.id) - rank(b.item.id) || a.i - b.i)
            .map(x => x.item);
    }

    FileView {
        id: store
        path: Quickshell.statePath("tray-order.json")
        onLoaded: {
            try {
                root.order = JSON.parse(text());
            } catch (e) {
                root.order = [];
            }
        }
    }

    function moveTo(item, index) {
        const ids = items.map(it => it.id).filter(id => id !== item.id);
        ids.splice(index, 0, item.id);
        order = ids.concat(order.filter(id => !ids.includes(id)));
        store.setText(JSON.stringify(order));
    }

    // Drag state: the item being dragged and the pointer x (in root)
    property var dragItem: null
    property real dragX: 0
    readonly property int dropIndex: Math.max(0, Math.min(items.length - 1, Math.floor(dragX / (slot + gap))))

    Row {
        id: row
        spacing: root.gap

        Repeater {
            model: root.items

            Item {
                id: trayItem
                required property var modelData
                required property int index
                readonly property bool dragging: root.dragItem === modelData

                width: root.slot
                height: root.slot

                // Where the dragged icon will land
                Rectangle {
                    visible: root.dragItem !== null && root.dropIndex === trayItem.index
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                    width: 12
                    height: 2
                    radius: 1
                    color: Theme.accent
                }

                // Hover pill + icon; follows the pointer while dragging
                Rectangle {
                    width: root.slot
                    height: root.slot
                    radius: 6
                    z: 1
                    x: trayItem.dragging ? root.dragX - trayItem.x - root.slot / 2 : 0
                    opacity: trayItem.dragging ? 0.8 : 1
                    color: trayItem.dragging || area.containsMouse || menu.visible ? "#26ffffff" : "transparent"

                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: trayItem.modelData.icon
                        sourceSize.width: 32
                        sourceSize.height: 32
                        smooth: true
                    }
                }

                TrayMenu {
                    id: menu
                    barWindow: root.barWindow
                    anchorItem: trayItem
                    handle: trayItem.modelData.menu
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: root.dragItem ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    property real pressX: 0
                    property bool dragged: false

                    onPressed: mouse => {
                        pressX = mouse.x;
                        dragged = false;
                    }

                    onPositionChanged: mouse => {
                        if (!(pressedButtons & Qt.LeftButton)) return;
                        if (!root.dragItem && Math.abs(mouse.x - pressX) > 6) {
                            root.dragItem = trayItem.modelData;
                            dragged = true;
                        }
                        if (root.dragItem) root.dragX = trayItem.mapToItem(root, mouse.x, 0).x;
                    }

                    onReleased: {
                        if (!root.dragItem) return;
                        const item = root.dragItem;
                        const index = root.dropIndex;
                        root.dragItem = null;
                        root.moveTo(item, index);
                    }

                    onClicked: mouse => {
                        if (dragged) return;
                        const item = trayItem.modelData;
                        if (mouse.button === Qt.MiddleButton)
                            item.secondaryActivate();
                        else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) menu.toggle();
                        } else
                            item.activate();
                    }

                    onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }
    }
}
