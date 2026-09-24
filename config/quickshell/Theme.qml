pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Wallpaper (video, played in Wallpaper.qml)
    readonly property string wallpaper: Quickshell.env("HOME") + "/Pictures/Wallpapers/zenitsu-white.webm"

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

    // Nerd Font battery glyphs, in steps of 10%
    function batteryIcon(percent, charging) {
        const step = Math.max(0, Math.min(10, Math.round(percent / 10)));
        const normal = ["\u{f008e}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}",
                        "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"];
        const plugged = ["\u{f089f}", "\u{f089c}", "\u{f0086}", "\u{f0087}", "\u{f0088}", "\u{f089d}",
                         "\u{f0089}", "\u{f089e}", "\u{f008a}", "\u{f008b}", "\u{f0085}"];
        return (charging ? plugged : normal)[step];
    }

    // Nerd Font network glyphs
    readonly property string ethernetIcon: "\u{f0200}"
    readonly property string wifiOffIcon: "\u{f092e}"
    readonly property string wifiNoneIcon: "\u{f092f}"   // on, not connected
    readonly property string lockIcon: "\u{f033e}"

    // Wi-Fi bars for signal strength 0..1; alert = connected but no internet
    function wifiIcon(strength, alert) {
        const bars = strength < 0.25 ? "\u{f091f}"
            : strength < 0.5 ? "\u{f0922}"
            : strength < 0.75 ? "\u{f0925}"
            : "\u{f0928}";
        // Each "-alert" glyph comes right after its bars glyph
        return alert ? String.fromCodePoint(bars.codePointAt(0) + 1) : bars;
    }
}
