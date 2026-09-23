import QtQuick
import Quickshell

// Right-click menu of a tray icon, drawn like the other bar popups
// (Qt's platform menus need QApplication mode and wouldn't match anyway).
// Submenus open in place, with a Back row.
BarPopup {
    id: popup

    required property var handle // SystemTrayItem.menu

    popupWidth: 250
    padding: 6
    spacing: 2

    // Submenu entries opened so far; the last one is shown
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : handle
    onAboutToOpen: stack = []

    QsMenuOpener {
        id: opener
        menu: popup.current
    }

    // Menu labels use "_" for keyboard mnemonics ("__" is a literal "_")
    function label(text) {
        return text.replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    component MenuRow: Rectangle {
        id: row
        property string text: ""
        property string icon: ""
        property string mark: ""       // check/radio column
        property bool submenu: false
        property bool active: true
        signal activated()

        width: parent.width
        height: 28
        radius: 6
        color: area.containsMouse && active ? "#ffffff" : "transparent"
        readonly property color fg: !active ? Theme.dim : area.containsMouse ? "#000000" : Theme.text

        Row {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                width: 12
                visible: row.mark !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: row.mark
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                color: row.fg
            }

            Image {
                width: 16
                height: 16
                visible: row.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                source: row.icon
                sourceSize.width: 32
                sourceSize.height: 32
                smooth: true
            }

            Text {
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                text: row.text
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                color: row.fg
            }
        }

        Text {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.submenu ? "\u{f0142}" : ""
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            color: row.fg
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (row.active) row.activated()
        }
    }

    // In a submenu: go back up
    MenuRow {
        visible: popup.stack.length > 0
        text: "Back"
        mark: "\u{f0141}"
        onActivated: popup.stack = popup.stack.slice(0, -1)
    }
    Separator {
        visible: popup.stack.length > 0
        width: parent.width
    }

    Repeater {
        model: opener.children

        Item {
            id: entry
            required property var modelData
            readonly property bool separator: modelData.isSeparator

            width: parent.width
            height: separator ? 9 : row.height

            Separator {
                visible: entry.separator
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
            }

            MenuRow {
                id: row
                visible: !entry.separator
                text: popup.label(entry.modelData.text)
                icon: entry.modelData.icon ?? ""
                submenu: entry.modelData.hasChildren
                active: entry.modelData.enabled
                mark: {
                    const m = entry.modelData;
                    const checked = m.checkState === Qt.Checked;
                    if (m.buttonType === QsMenuButtonType.CheckBox) return checked ? "\u{f012c}" : " ";
                    if (m.buttonType === QsMenuButtonType.RadioButton) return checked ? "\u{f0765}" : "\u{f0766}";
                    return "";
                }

                onActivated: {
                    if (entry.modelData.hasChildren) {
                        popup.stack = popup.stack.concat([entry.modelData]);
                    } else {
                        entry.modelData.triggered();
                        popup.visible = false;
                    }
                }
            }
        }
    }
}
