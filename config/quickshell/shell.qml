import Quickshell

ShellRoot {
    // Singletons load on first use; load Mixer now so its IPC target exists
    readonly property var mixer: Mixer
    readonly property var keyboard: KeyboardSettings

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Wallpaper {
                id: wallpaper
                screen: perScreen.modelData
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
