import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Volume panel under the bar's volume icon: output/mic sliders and output device picker
BarPopup {
    id: popup
    alignRight: true

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [popup.sink, popup.source].filter(n => n !== null)
    }

    SectionLabel { text: "OUTPUT" }

    VolumeRow {
        width: parent.width
        node: popup.sink
    }

    SectionLabel { text: "MICROPHONE" }

    VolumeRow {
        width: parent.width
        node: popup.source
        glyph: muted ? "\u{f036d}" : "\u{f036c}"
    }

    Separator { width: parent.width }

    SectionLabel { text: "DEVICE" }

    DeviceList { width: parent.width }

    Separator { width: parent.width }

    Text {
        text: "\u{f0493}  Sound settings"
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: settingsArea.containsMouse ? Theme.text : Theme.dim

        MouseArea {
            id: settingsArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                popup.visible = false;
                Mixer.open();
            }
        }
    }
}
