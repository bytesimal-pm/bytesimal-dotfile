import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Row {
    id: root
    spacing: 8

    required property var barWindow

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData

            width: 18
            height: 18

            Image {
                anchors.fill: parent
                source: trayItem.modelData.icon
                sourceSize.width: 18
                sourceSize.height: 18
                smooth: true
            }

            QsMenuAnchor {
                id: menu
                menu: trayItem.modelData.menu
                anchor.window: root.barWindow
                anchor.rect.x: trayItem.mapToItem(null, 0, 0).x
                anchor.rect.y: trayItem.mapToItem(null, 0, 0).y + trayItem.height + 8
                anchor.rect.width: trayItem.width
                anchor.rect.height: 1
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    const item = trayItem.modelData;
                    if (mouse.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) menu.open();
                    } else
                        item.activate();
                }

                onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
