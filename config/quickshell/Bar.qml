import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: bar

    // Hide while the workspace shown on this monitor has a fullscreen window
    readonly property HyprlandWorkspace shownWorkspace: Hyprland.monitorFor(screen)?.activeWorkspace ?? null
    visible: !(shownWorkspace?.hasFullscreen ?? false)

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.marginTop
        left: Theme.marginSide
        right: Theme.marginSide
    }

    implicitHeight: Theme.height
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
        }

        Clock {
            anchors.centerIn: parent
            barWindow: bar
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing

            Tray {
                barWindow: bar
            }
            Network {
                barWindow: bar
            }
            BluetoothIcon {
                barWindow: bar
            }
            Volume {
                barWindow: bar
            }
            Battery {
                barWindow: bar
            }
        }
    }
}
