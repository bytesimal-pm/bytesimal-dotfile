import QtQuick
import Quickshell
import Quickshell.Networking

// Internet icon in the bar (Ethernet or Wi-Fi, whichever is up)
Item {
    id: root
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    required property var barWindow

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var activeWifi: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wiredUp: wired.some(d => d.connected)
    readonly property bool online: wiredUp || activeWifi !== null
    // Connected, but NetworkManager's check can't reach the internet
    readonly property bool limited: online
        && (Networking.connectivity === NetworkConnectivity.Limited
            || Networking.connectivity === NetworkConnectivity.Portal
            || Networking.connectivity === NetworkConnectivity.None)

    Text {
        id: icon
        text: root.wiredUp ? Theme.ethernetIcon
            : root.activeWifi ? Theme.wifiIcon(root.activeWifi.signalStrength, root.limited)
            : !Networking.wifiEnabled ? Theme.wifiOffIcon
            : Theme.wifiNoneIcon
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 2
        color: root.online ? Theme.text : Theme.dim
    }

    NetworkPopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
        net: root
    }

    // Left: open the panel, right: Wi-Fi on/off
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                popup.toggle();
            else
                Networking.wifiEnabled = !Networking.wifiEnabled;
        }
    }
}
