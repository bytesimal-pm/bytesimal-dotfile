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
                screen: perScreen.modelData
            }
            Bar {
                screen: perScreen.modelData
            }
        }
    }

    Launcher {}
}
