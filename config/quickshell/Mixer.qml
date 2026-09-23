pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Sound settings window with per-app volume. Open from the volume panel,
// or with: qs ipc call mixer toggle
Singleton {
    id: mixer

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    readonly property var playback: streams.filter(n => n.isSink)   // apps playing audio
    readonly property var recording: streams.filter(n => !n.isSink) // apps using the mic

    function open() {
        scroll.contentY = 0;
        win.visible = true;
    }
    function close() { win.visible = false; }
    function toggle() { win.visible ? close() : open(); }

    // Close when switching workspace
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { mixer.close(); }
    }

    IpcHandler {
        target: "mixer"
        function toggle(): void { mixer.toggle(); }
        function open(): void { mixer.open(); }
        function close(): void { mixer.close(); }
    }

    // Keeps volume/mute live while the window is open
    PwObjectTracker {
        objects: win.visible ? [mixer.sink, mixer.source, ...mixer.streams].filter(n => n !== null) : []
    }

    // Icon, app name, what it's playing, then mute + slider + percent
    component AppRow: Row {
        id: app
        required property PwNode modelData
        property bool mic: false
        readonly property var props: modelData.properties ?? {}
        readonly property string appName: props["application.name"] || modelData.description || modelData.name
        readonly property string media: props["media.name"] ?? ""

        spacing: 12

        Item {
            id: icon
            width: 32
            height: 32

            // "" when the icon theme doesn't have it
            readonly property string path: Quickshell.iconPath(
                app.props["application.icon-name"] || app.props["application.process.binary"] || "", true)

            Image {
                anchors.fill: parent
                visible: icon.path !== ""
                source: icon.path
                sourceSize.width: 32
                sourceSize.height: 32
                smooth: true
            }

            // Fallback: first letter of the app name
            Rectangle {
                anchors.fill: parent
                visible: icon.path === ""
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: Theme.text

                Text {
                    anchors.centerIn: parent
                    text: app.appName.charAt(0).toUpperCase()
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.text
                }
            }
        }

        Column {
            width: app.width - icon.width - app.spacing
            spacing: 2

            Text {
                width: parent.width
                text: app.appName
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                color: Theme.text
            }

            Text {
                width: parent.width
                visible: text !== "" && text !== app.appName
                text: app.media
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                color: Theme.dim
            }

            VolumeRow {
                width: parent.width
                node: app.modelData
                glyph: app.mic ? (muted ? "\u{f036d}" : "\u{f036c}") : Theme.speakerIcon(muted, percent)
            }
        }
    }

    component Link: Text {
        id: link
        signal clicked()
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        color: linkArea.containsMouse ? Theme.text : Theme.dim

        MouseArea {
            id: linkArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    FloatingWindow {
        id: win
        visible: false
        title: "Sound Settings"
        implicitWidth: 460
        implicitHeight: 560
        minimumSize: Qt.size(360, 320)
        color: "#cc000000"

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: mixer.close()

            // Header
            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                height: 28

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f057e}  Sound Settings"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    color: Theme.text
                }

                Link {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f0156}" // close
                    font.pixelSize: Theme.fontSize + 6
                    onClicked: mixer.close()
                }
            }

            Separator {
                id: headerLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.topMargin: 12
            }

            Flickable {
                id: scroll
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerLine.bottom
                anchors.bottom: footerLine.top
                anchors.margins: 18
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body
                    width: scroll.width
                    spacing: 12

                    SectionLabel { text: "OUTPUT" }

                    VolumeRow {
                        width: parent.width
                        node: mixer.sink
                    }

                    DeviceList { width: parent.width }

                    Separator { width: parent.width }

                    SectionLabel { text: "APPLICATIONS" }

                    Text {
                        visible: mixer.playback.length === 0
                        text: "No apps are playing audio"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        color: Theme.dim
                    }

                    Repeater {
                        model: mixer.playback
                        AppRow { width: body.width }
                    }

                    Separator {
                        width: parent.width
                        visible: mixer.recording.length > 0
                    }

                    SectionLabel {
                        visible: mixer.recording.length > 0
                        text: "RECORDING"
                    }

                    Repeater {
                        model: mixer.recording
                        AppRow {
                            width: body.width
                            mic: true
                        }
                    }

                    Separator { width: parent.width }

                    SectionLabel { text: "MICROPHONE" }

                    VolumeRow {
                        width: parent.width
                        node: mixer.source
                        glyph: muted ? "\u{f036d}" : "\u{f036c}"
                    }
                }
            }

            Separator {
                id: footerLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.bottomMargin: 12
            }

            Link {
                id: footer
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 18
                text: "\u{f0493}  Advanced (pavucontrol)"
                onClicked: {
                    mixer.close();
                    Quickshell.execDetached(["pavucontrol"]);
                }
            }
        }
    }
}
