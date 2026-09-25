import QtQuick
import Quickshell
import Quickshell.Wayland

// Login screen for greetd. Wallpaper.qml, Theme.qml and GlitchReveal.qml are the desktop's
// (install.sh copies them next to this file in /etc/greetd/quickshell).
ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            Wallpaper {
                screen: perScreen.modelData
            }

            // Fades every screen to black after login (LoginPanel.blackout)
            PanelWindow {
                screen: perScreen.modelData
                visible: login.blackout > 0
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-greeter"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: login.blackout
                }
            }
        }
    }

    LoginPanel {
        id: login
    }
}
