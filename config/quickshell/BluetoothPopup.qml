import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth panel under the bar's Bluetooth icon: on/off, paired and nearby devices
BarPopup {
    id: popup
    alignRight: true

    required property var adapter
    readonly property bool enabled: adapter !== null && adapter.enabled

    // Address of the device row showing its actions ("" = none)
    property string expanded: ""
    // { address, text } of the last failed pairing
    property var error: null

    readonly property int rowHeight: 30
    readonly property int maxRows: 8

    // Nearby devices that only have a MAC address aren't worth listing
    function hasName(d) { return d.deviceName !== "" && d.name !== d.address.replace(/:/g, "-"); }

    // Paired (connected first), then unpaired ones with a name
    readonly property var liveDevices: {
        if (!adapter) return [];
        const all = adapter.devices.values;
        const paired = all.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name));
        const nearby = all.filter(d => !d.paired && hasName(d)).sort((a, b) => a.name.localeCompare(b.name));
        return paired.concat(nearby);
    }
    // While a row is open the list is frozen, so scan results don't move it
    property var frozenDevices: []
    readonly property var devices: expanded !== "" ? frozenDevices : liveDevices
    readonly property var pairedDevices: devices.filter(d => d.paired)
    readonly property var nearbyDevices: devices.filter(d => !d.paired)

    function expand(d) {
        if (expanded === d.address) {
            expanded = "";
            return;
        }
        frozenDevices = liveDevices;
        expanded = d.address;
    }

    function busy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    function activate(d) {
        error = null;
        if (busy(d)) return;
        if (d.connected) expand(d);
        else if (d.paired) { expanded = ""; d.connect(); }
        else {
            // No pairing agent here, so BlueZ does "Just Works" pairing;
            // connect once it's paired (see the Connections in the row)
            expanded = "";
            d.trusted = true;
            d.pair();
        }
    }

    onAboutToOpen: {
        expanded = "";
        error = null;
        list.contentY = 0;
    }

    // Scan only while the panel is open
    Binding {
        target: popup.adapter
        property: "discovering"
        value: popup.visible
        when: popup.enabled
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.text
        elide: Text.ElideRight
    }

    // ── Header ──

    Item {
        width: parent.width
        height: Math.max(header.height, toggle.height)

        SectionLabel {
            id: header
            anchors.verticalCenter: parent.verticalCenter
            text: "BLUETOOTH"
        }

        Switch {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: popup.enabled
            onToggled: popup.adapter.enabled = !popup.adapter.enabled
        }
    }

    Label {
        visible: !popup.enabled || popup.devices.length === 0
        color: Theme.dim
        text: popup.adapter && popup.adapter.state === BluetoothAdapterState.Blocked ? "Blocked by the hardware switch"
            : !popup.enabled ? "Bluetooth is off"
            : "Scanning…"
    }

    // ── Devices ──

    Flickable {
        id: list
        width: parent.width
        height: Math.min(contentHeight, popup.maxRows * (popup.rowHeight + 2) + 30)
        visible: popup.enabled && popup.devices.length > 0
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            width: list.width
            spacing: 2

            Repeater {
                model: popup.devices

                Column {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property var dev: modelData
                    readonly property bool isExpanded: popup.expanded === dev.address
                    readonly property bool failed: popup.error !== null && popup.error.address === dev.address
                    // First unpaired device starts the "AVAILABLE" section
                    readonly property bool firstNearby: !dev.paired && index === popup.pairedDevices.length

                    width: rows.width
                    spacing: 4

                    Connections {
                        target: entry.dev
                        function onPairedChanged() {
                            if (entry.dev.paired) entry.dev.connect();
                        }
                        function onPairingChanged() {
                            if (!entry.dev.pairing && !entry.dev.paired)
                                popup.error = { address: entry.dev.address, text: "Needs a PIN: pair it with bluetoothctl" };
                        }
                    }

                    SectionLabel {
                        visible: entry.firstNearby
                        topPadding: entry.index > 0 ? 6 : 0
                        bottomPadding: 2
                        text: "AVAILABLE"
                    }

                    ListRow {
                        id: row
                        width: parent.width
                        height: popup.rowHeight
                        active: entry.dev.connected
                        onClicked: mouse => {
                            // Right click: actions of a paired device (forget)
                            if (mouse.button === Qt.RightButton && entry.dev.paired)
                                popup.expand(entry.dev);
                            else if (mouse.button === Qt.LeftButton)
                                popup.activate(entry.dev);
                        }

                        Label {
                            id: glyph
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            text: Theme.deviceIcon(entry.dev.icon)
                            color: row.active ? "#000000" : Theme.text
                        }

                        Label {
                            anchors.left: glyph.right
                            anchors.right: status.left
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.dev.name
                            font.bold: row.active
                            color: row.active ? "#000000" : Theme.text
                        }

                        Label {
                            id: status
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSize - 1
                            color: row.active ? "#000000" : Theme.dim
                            text: popup.busy(entry.dev) ? "…"
                                : entry.dev.connected && entry.dev.batteryAvailable ? Math.round(entry.dev.battery * 100) + "%"
                                : !entry.dev.paired ? "Pair"
                                : ""
                        }
                    }

                    Label {
                        visible: entry.failed
                        x: 10
                        width: parent.width - 20
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.dim
                        text: entry.failed ? "\u{f0026}  " + popup.error.text : ""
                    }

                    // Paired device: connect/disconnect, forget
                    Row {
                        visible: entry.isExpanded
                        x: 10
                        spacing: 18
                        bottomPadding: 4

                        TextButton {
                            text: entry.dev.connected ? "Disconnect" : "Connect"
                            onClicked: {
                                popup.expanded = "";
                                entry.dev.connected ? entry.dev.disconnect() : entry.dev.connect();
                            }
                        }
                        TextButton {
                            text: "Forget"
                            onClicked: {
                                popup.expanded = "";
                                entry.dev.forget();
                            }
                        }
                    }
                }
            }
        }
    }
}
