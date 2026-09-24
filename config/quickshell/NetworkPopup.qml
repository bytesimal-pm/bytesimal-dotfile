import QtQuick
import Quickshell
import Quickshell.Networking

// Internet panel under the bar's network icon: status, Ethernet, Wi-Fi list
BarPopup {
    id: popup
    alignRight: true

    // The bar item (Network.qml): devices and connection state
    required property var net
    readonly property var wifi: net.wifi

    // Name of the Wi-Fi row showing its actions or password field ("" = none)
    property string expanded: ""
    property bool wantPassword: false
    // { name, text } of the last failed connection
    property var error: null

    readonly property int rowHeight: 30
    readonly property int maxRows: 8

    // One entry per name (strongest), connected first, then saved, then by signal
    readonly property var liveNetworks: {
        if (!wifi) return [];
        const best = {};
        for (const n of wifi.networks.values) {
            if (!n.name) continue;
            const prev = best[n.name];
            if (!prev || n.connected || (!prev.connected && n.signalStrength > prev.signalStrength))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    // While a row is open the list is frozen, so re-sorting after a scan
    // doesn't rebuild the rows (and wipe a half-typed password)
    property var frozenNetworks: []
    readonly property var networks: expanded !== "" ? frozenNetworks : liveNetworks

    function expand(name, password) {
        if (expanded === name && wantPassword === password) {
            expanded = "";
            return;
        }
        frozenNetworks = liveNetworks;
        wantPassword = password;
        expanded = name;
    }

    function isOpen(n) { return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe; }
    function isEnterprise(n) {
        return [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.Wpa3SuiteB192,
                WifiSecurityType.Leap, WifiSecurityType.DynamicWep].includes(n.security);
    }

    function activate(n) {
        error = null;
        if (n.connected) expand(n.name, false);
        else if (n.stateChanging) return;
        else if (n.known || isOpen(n)) { expanded = ""; n.connect(); }
        else if (isEnterprise(n)) error = { name: n.name, text: "Enterprise network: set it up with nmcli" };
        else expand(n.name, true);
    }

    onAboutToOpen: {
        expanded = "";
        error = null;
        list.contentY = 0;
    }

    // Scan only while the panel is open
    Binding {
        target: popup.wifi
        property: "scannerEnabled"
        value: popup.visible
        when: popup.wifi !== null
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: Theme.text
        elide: Text.ElideRight
    }

    // ── Status ──

    Item {
        width: parent.width
        height: statusLabel.height

        SectionLabel { id: statusLabel; text: "INTERNET" }

        Label {
            anchors.right: parent.right
            anchors.left: statusLabel.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSize - 1
            color: popup.net.online && !popup.net.limited ? Theme.text : Theme.dim
            text: !popup.net.online ? "Offline"
                : Networking.connectivity === NetworkConnectivity.Portal ? "Sign-in required"
                : popup.net.limited ? "No internet access"
                : popup.net.wiredUp ? "Ethernet"
                : popup.net.activeWifi.name
        }
    }

    // ── Ethernet ──

    Separator { width: parent.width; visible: popup.net.wired.length > 0 }

    SectionLabel { text: "ETHERNET"; visible: popup.net.wired.length > 0 }

    Column {
        width: parent.width
        spacing: 2
        visible: popup.net.wired.length > 0

        Repeater {
            model: popup.net.wired

            ListRow {
                id: wiredRow
                required property var modelData
                readonly property bool changing: modelData.state === ConnectionState.Connecting
                    || modelData.state === ConnectionState.Disconnecting

                width: parent.width
                active: modelData.connected
                onClicked: mouse => {
                    if (changing || mouse.button !== Qt.LeftButton) return;
                    if (modelData.connected) modelData.disconnect();
                    else if (modelData.hasLink && modelData.network) modelData.network.connect();
                }

                Label {
                    id: wiredName
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.ethernetIcon + "  " + wiredRow.modelData.name
                    font.bold: wiredRow.active
                    color: wiredRow.active ? "#000000" : Theme.text
                }

                Label {
                    anchors.right: parent.right
                    anchors.left: wiredName.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: Theme.fontSize - 1
                    color: wiredRow.active ? "#000000" : Theme.dim
                    text: wiredRow.changing ? "…"
                        : !wiredRow.modelData.hasLink ? "Cable unplugged"
                        : wiredRow.modelData.connected
                            ? (wiredRow.modelData.linkSpeed > 0 ? `${wiredRow.modelData.linkSpeed} Mb/s` : "Connected")
                        : "Connect"
                }
            }
        }
    }

    // ── Wi-Fi ──

    Separator { width: parent.width; visible: popup.wifi !== null }

    Item {
        width: parent.width
        height: Math.max(wifiLabel.height, toggle.height)
        visible: popup.wifi !== null

        SectionLabel {
            id: wifiLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "WI-FI"
        }

        Switch {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: Networking.wifiEnabled
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Label {
        visible: popup.wifi !== null && popup.networks.length === 0
        color: Theme.dim
        text: !Networking.wifiHardwareEnabled ? "Blocked by the hardware switch"
            : !Networking.wifiEnabled ? "Wi-Fi is off"
            : "Scanning…"
    }

    Flickable {
        id: list
        width: parent.width
        height: Math.min(contentHeight, popup.maxRows * (popup.rowHeight + 2))
        visible: popup.wifi !== null && Networking.wifiEnabled && popup.networks.length > 0
        contentHeight: rows.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: rows
            width: list.width
            spacing: 2

            Repeater {
                model: popup.networks

                Column {
                    id: entry
                    required property var modelData
                    readonly property bool isExpanded: popup.expanded === modelData.name
                    readonly property bool failed: popup.error !== null && popup.error.name === modelData.name

                    width: rows.width
                    spacing: 4

                    // Password was rejected or is missing: ask for it
                    Connections {
                        target: entry.modelData
                        function onConnectionFailed(reason) {
                            const noSecrets = reason === ConnectionFailReason.NoSecrets;
                            popup.error = {
                                name: entry.modelData.name,
                                text: noSecrets ? "Wrong or missing password" : ConnectionFailReason.toString(reason),
                            };
                            if (noSecrets && !popup.isOpen(entry.modelData)) {
                                popup.expanded = "";
                                popup.expand(entry.modelData.name, true);
                            }
                        }
                    }

                    ListRow {
                        id: wifiRow
                        width: parent.width
                        active: entry.modelData.connected
                        onClicked: mouse => {
                            // Right click: actions of a saved network (forget)
                            if (mouse.button === Qt.RightButton && entry.modelData.known)
                                popup.expand(entry.modelData.name, false);
                            else if (mouse.button === Qt.LeftButton)
                                popup.activate(entry.modelData);
                        }

                        Label {
                            id: bars
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            text: Theme.wifiIcon(entry.modelData.signalStrength, false)
                            color: wifiRow.active ? "#000000" : Theme.text
                        }

                        Label {
                            anchors.left: bars.right
                            anchors.right: status.left
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.name
                            font.bold: wifiRow.active
                            color: wifiRow.active ? "#000000" : Theme.text
                        }

                        Label {
                            id: status
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSize - 1
                            color: wifiRow.active ? "#000000" : Theme.dim
                            text: entry.modelData.stateChanging ? "…"
                                : entry.modelData.known && !entry.modelData.connected ? "saved"
                                : popup.isOpen(entry.modelData) || entry.modelData.known ? ""
                                : Theme.lockIcon
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

                    // Saved network: disconnect / forget
                    Row {
                        visible: entry.isExpanded && !popup.wantPassword
                        x: 10
                        spacing: 18
                        bottomPadding: 4

                        TextButton {
                            text: entry.modelData.connected ? "Disconnect" : "Connect"
                            onClicked: {
                                popup.expanded = "";
                                entry.modelData.connected ? entry.modelData.disconnect() : entry.modelData.connect();
                            }
                        }
                        TextButton {
                            visible: entry.modelData.known
                            text: "Forget"
                            onClicked: {
                                popup.expanded = "";
                                entry.modelData.forget();
                            }
                        }
                    }

                    // New secured network: password field
                    Rectangle {
                        id: pwBox
                        visible: entry.isExpanded && popup.wantPassword
                        width: parent.width
                        height: popup.rowHeight
                        radius: 6
                        color: "transparent"
                        border.color: password.activeFocus ? Theme.text : Theme.border
                        border.width: 1

                        function submit() {
                            if (password.text.length < 8) return; // WPA needs 8+ characters
                            popup.error = null;
                            popup.expanded = "";
                            entry.modelData.connectWithPsk(password.text);
                        }

                        onVisibleChanged: {
                            password.text = "";
                            password.reveal = false;
                            if (visible) password.forceActiveFocus();
                        }

                        TextInput {
                            id: password
                            property bool reveal: false
                            anchors.left: parent.left
                            anchors.right: eye.left
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            echoMode: reveal ? TextInput.Normal : TextInput.Password
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            color: Theme.text
                            selectionColor: "#ffffff"
                            selectedTextColor: "#000000"
                            onAccepted: pwBox.submit()
                            Keys.onEscapePressed: popup.expanded = ""

                            Label {
                                visible: password.text === ""
                                text: "Password"
                                color: Theme.dim
                            }
                        }

                        TextButton {
                            id: eye
                            anchors.right: go.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: password.reveal ? "\u{f0209}" : "\u{f0208}"
                            onClicked: password.reveal = !password.reveal
                        }

                        TextButton {
                            id: go
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{f0054}"
                            color: password.text.length >= 8 ? Theme.text : Theme.dim
                            onClicked: pwBox.submit()
                        }
                    }
                }
            }
        }
    }
}
