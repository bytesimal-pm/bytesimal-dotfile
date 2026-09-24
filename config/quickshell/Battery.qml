import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery icon + percentage in the bar. Only shown on laptops
// (hidden items take no space in the bar's RowLayout).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    required property var barWindow

    // UPower's combined view of all batteries
    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property bool present: dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property int percent: Math.round(dev.percentage * 100)
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
        || dev.state === UPowerDeviceState.FullyCharged
        || dev.state === UPowerDeviceState.PendingCharge
    readonly property bool low: !charging && percent < 15

    visible: present

    Row {
        id: row
        spacing: 4

        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.batteryIcon(root.percent, root.charging)
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            color: Theme.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: icon.color
        }
    }

    // Low and discharging: blink the icon
    SequentialAnimation {
        running: root.present && root.low
        loops: Animation.Infinite
        onRunningChanged: if (!running) icon.color = Theme.text

        ColorAnimation { target: icon; property: "color"; to: Theme.dim; duration: 600 }
        ColorAnimation { target: icon; property: "color"; to: Theme.text; duration: 600 }
    }

    BatteryPopup {
        id: popup
        barWindow: root.barWindow
        anchorItem: root
        dev: root.dev
        charging: root.charging
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }
}
