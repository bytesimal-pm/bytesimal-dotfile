import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Singletons load on first use; load Mixer now so its IPC target exists
    readonly property var mixer: Mixer
    readonly property var keyboard: KeyboardSettings

    // qs ipc call wallpaper toggle / on / off (black desktop, video stopped; resets on qs restart)
    property bool wallpaperOff: false
    signal wallpaperVacuum()
    signal wallpaperGlint()
    IpcHandler {
        target: "wallpaper"
        function vacuum(): void { root.wallpaperVacuum(); }
        function glint(): void { root.wallpaperGlint(); }
        function toggle(): void { root.wallpaperOff = !root.wallpaperOff; }
        function on(): void { root.wallpaperOff = false; }
        function off(): void { root.wallpaperOff = true; }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Wallpaper {
                id: wallpaper
                screen: perScreen.modelData
                off: root.wallpaperOff
            }
            Connections {
                target: root
                function onWallpaperVacuum() { wallpaper.vacuum(); }
                function onWallpaperGlint() { wallpaper.glint(); }
            }
            Bar {
                id: bar
                screen: perScreen.modelData
            }
            Glitch {
                screen: perScreen.modelData
            }
            WindowGlitch {
                screen: perScreen.modelData
            }
            // Boot screen after login, until the wallpaper and bar are up
            Splash {
                screen: perScreen.modelData
                wallpaper: wallpaper
                bar: bar
            }
        }
    }

    Launcher {}
}
