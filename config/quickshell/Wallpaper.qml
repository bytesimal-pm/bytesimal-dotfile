import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"

    Video {
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: true
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
