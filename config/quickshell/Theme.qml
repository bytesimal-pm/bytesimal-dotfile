pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Wallpaper (video, played in Wallpaper.qml)
    readonly property string wallpaper: Quickshell.env("HOME") + "/Pictures/Wallpapers/anime-eye.mp4"

    // Colors (monochrome, to match the wallpaper)
    readonly property color bg: "#99000000"      // ~60% opaque black
    readonly property color border: "#26ffffff"
    readonly property color text: "#e6e6e6"
    readonly property color dim: "#707070"
    readonly property color accent: "#e6e6e6"    // active workspace pill

    // Font
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12

    // Size
    readonly property int height: 36
    readonly property int radius: 10              // matches Hyprland window rounding
    readonly property int marginTop: 10
    readonly property int marginSide: 20          // matches Hyprland gaps_out
    readonly property int padding: 12
    readonly property int spacing: 14

    // Nerd Font speaker glyphs: muted / low / medium / high
    function speakerIcon(muted, percent) {
        return muted || percent === 0 ? "\u{f075f}"
            : percent < 34 ? "\u{f057f}"
            : percent < 67 ? "\u{f0580}"
            : "\u{f057e}";
    }
}
