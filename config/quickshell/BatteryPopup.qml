import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery details under the bar's battery icon
BarPopup {
    id: popup
    alignRight: true
    popupWidth: 240

    required property UPowerDevice dev
    required property bool charging

    // Seconds → "2h 05m"; "" when UPower doesn't know yet (0)
    function duration(s) {
        if (s <= 0) return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor(s % 3600 / 60);
        return h > 0 ? h + "h " + String(m).padStart(2, "0") + "m" : m + "m";
    }

    readonly property string timeText: duration(charging ? dev.timeToFull : dev.timeToEmpty)

    SectionLabel { text: "BATTERY" }

    component InfoRow: Item {
        property string label
        property string value
        width: parent.width
        implicitHeight: valueText.implicitHeight
        visible: value !== ""

        Text {
            text: parent.label
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.dim
        }
        Text {
            id: valueText
            anchors.right: parent.right
            text: parent.value
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.text
        }
    }

    InfoRow {
        label: "Charge"
        value: Math.round(popup.dev.percentage * 100) + "%"
    }
    InfoRow {
        label: "Status"
        value: UPowerDeviceState.toString(popup.dev.state)
    }
    InfoRow {
        label: popup.charging ? "Full in" : "Time left"
        value: popup.timeText
    }
    InfoRow {
        label: "Power"
        value: popup.dev.changeRate > 0 ? popup.dev.changeRate.toFixed(1) + " W" : ""
    }
    InfoRow {
        label: "Health"
        value: popup.dev.healthSupported ? Math.round(popup.dev.healthPercentage) + "%" : ""
    }
}
