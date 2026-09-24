import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth icon in the bar (not named Bluetooth.qml: that would shadow the
// Quickshell.Bluetooth singleton). Hidden without an adapter (or without BlueZ).
Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    required property var barWindow

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter !== null && adapter.enabled
    readonly property bool connected: enabled && adapter.devices.values.some(d => d.connected)

    visible: adapter !== null

    Text {
        id: icon
        text: !root.enabled ? Theme.bluetoothOffIcon
            : root.connected ? Theme.bluetoothConnectedIcon
            : Theme.bluetoothIcon
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 2
        color: root.enabled ? Theme.text : Theme.dim
    }

    BluetoothPopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
        adapter: root.adapter
    }

    // Left: open the panel, right: Bluetooth on/off
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                popup.toggle();
            else if (root.adapter)
                root.adapter.enabled = !root.adapter.enabled;
        }
    }
}
