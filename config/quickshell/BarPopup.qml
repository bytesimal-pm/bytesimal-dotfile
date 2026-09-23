import QtQuick
import Quickshell

// Popup box that opens below a bar item. Children go into a padded Column.
// Centered under the item, or right-aligned with its right edge (alignRight).
PopupWindow {
    id: popup

    required property var barWindow
    required property Item anchorItem
    property bool alignRight: false
    property int popupWidth: 320
    default property alias content: body.data

    // Emitted right before it becomes visible
    signal aboutToOpen()

    visible: false
    color: "transparent"
    // Compositor popup grab: clicks inside stay here, a click outside closes it
    grabFocus: true
    implicitWidth: popupWidth
    implicitHeight: body.implicitHeight + 28

    // Popup top sits 8px below the bar
    anchor.window: barWindow
    anchor.edges: alignRight ? Edges.Bottom | Edges.Right : Edges.Bottom
    anchor.gravity: alignRight ? Edges.Bottom | Edges.Left : Edges.Bottom

    // Clicking the bar item while open: the grab closes the popup first,
    // then the click toggles it. Don't reopen right after that close.
    property real closedAt: 0
    onVisibleChanged: if (!visible) closedAt = Date.now()

    function toggle() {
        if (visible) {
            visible = false;
            return;
        }
        if (Date.now() - closedAt < 250) return;
        const p = anchorItem.mapToItem(null, 0, 0);
        anchor.rect.x = p.x;
        anchor.rect.y = 0;
        anchor.rect.width = anchorItem.width;
        anchor.rect.height = barWindow.height + 8;
        aboutToOpen();
        visible = true;
    }

    Rectangle {
        anchors.fill: parent
        color: "#cc000000"
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
        }
    }
}
