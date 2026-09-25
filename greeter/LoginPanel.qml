import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Greetd

// Login box under the wallpaper clock. Talks to greetd: createSession(user), answer the
// password prompt, then launch Hyprland. Without greetd (testing with `qs -p greeter/`)
// Enter only plays the glitch out and back in.
PanelWindow {
    id: panel

    screen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    // Same spot as the clock in Wallpaper.qml (x 7%), just below the date
    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.round((screen?.height ?? 1080) * 0.75)
        left: Math.round((screen?.width ?? 1920) * 0.07) - shakeRoom
    }
    readonly property int shakeRoom: 16
    implicitWidth: box.width + shakeRoom * 2
    implicitHeight: box.height + footer.height + 14

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-greeter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Login accounts from /etc/passwd: UID 1000+ with a real shell
    property var users: []
    property int userIndex: 0
    readonly property string user: users[userIndex] ?? ""

    property bool busy: false        // talking to greetd
    property bool launching: false
    property bool answered: false    // password sent; a second prompt (e.g. 2FA) is typed by hand
    property string message: Greetd.available ? "" : "greetd not available (test mode)"

    // 0..1: the whole screen fades to black (shell.qml) before the session starts, so the
    // gap between the two compositors doesn't flash
    property real blackout: 0
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: panel; property: "blackout"; to: 1; duration: 350; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                if (Greetd.available) {
                    // Clear tty1 and hide its cursor: it shows between the two compositors
                    Greetd.launch(["sh", "-c", "printf '\\033[2J\\033[H\\033[?25l' 2>/dev/null; exec start-hyprland >/dev/null 2>&1"], [
                        "XDG_SESSION_TYPE=wayland",
                        "XDG_CURRENT_DESKTOP=Hyprland",
                        "XDG_SESSION_DESKTOP=Hyprland",
                    ], true);
                } else {
                    fadeBack.start();
                }
            }
        }
    }
    // Test mode: come back
    SequentialAnimation {
        id: fadeBack
        PauseAnimation { duration: 400 }
        NumberAnimation { target: panel; property: "blackout"; to: 0; duration: 350 }
        ScriptAction {
            script: {
                box.visible = true;
                panel.launching = false;
                reveal.open();
            }
        }
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: {
            const list = [];
            for (const line of text().split("\n")) {
                const f = line.split(":");
                const uid = parseInt(f[2]);
                if (f.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6]))
                    list.push(f[0]);
            }
            panel.users = list;
        }
    }

    Component.onCompleted: {
        password.forceActiveFocus();
        reveal.open();
    }

    function submit(): void {
        if (busy || launching || user === "")
            return;
        if (!Greetd.available) {
            launching = true;
            reveal.close();
            return;
        }
        busy = true;
        message = "";
        if (Greetd.state === GreetdState.Authenticating && answered) {
            // Extra prompt after the password: send what was typed now
            Greetd.respond(password.text);
            password.text = "";
            return;
        }
        answered = false;
        Greetd.createSession(user);
    }

    function fail(text: string): void {
        busy = false;
        answered = false;
        message = text || "Login failed";
        password.text = "";
        password.forceActiveFocus();
        shake.restart();
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
    }

    function pickUser(step: int): void {
        if (users.length < 2 || busy)
            return;
        userIndex = (userIndex + step + users.length) % users.length;
        message = "";
    }

    Connections {
        target: Greetd

        function onAuthMessage(text: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired && !panel.answered) {
                panel.answered = true;
                Greetd.respond(password.text);
                password.text = "";
                return;
            }
            panel.message = text;
            if (responseRequired) {
                // Another prompt: let the user answer it
                panel.busy = false;
                password.echoMode = echoResponse ? TextInput.Normal : TextInput.Password;
                password.forceActiveFocus();
            }
        }
        function onAuthFailure(text: string): void { panel.fail(text); }
        function onError(text: string): void { panel.fail(text); }
        function onReadyToLaunch(): void {
            panel.launching = true;
            reveal.close();
        }
    }

    Rectangle {
        id: box
        x: panel.shakeRoom + shakeOffset
        width: 340
        height: column.implicitHeight + 24
        color: "#cc000000"
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        property real shakeOffset: 0
        SequentialAnimation {
            id: shake
            NumberAnimation { target: box; property: "shakeOffset"; to: -12; duration: 40 }
            NumberAnimation { target: box; property: "shakeOffset"; to: 10; duration: 60 }
            NumberAnimation { target: box; property: "shakeOffset"; to: -6; duration: 60 }
            NumberAnimation { target: box; property: "shakeOffset"; to: 3; duration: 60 }
            NumberAnimation { target: box; property: "shakeOffset"; to: 0; duration: 50 }
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // User (Up/Down or click the arrows when there are several)
            Row {
                width: parent.width
                height: 28
                spacing: 10
                leftPadding: 6

                Text {
                    text: "\u{f0004}"
                    font.family: Theme.font
                    font.pixelSize: 16
                    color: Theme.dim
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - 90
                    text: panel.user || "…"
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Theme.text
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextButton {
                    visible: panel.users.length > 1
                    text: "\u{f0141}"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: panel.pickUser(-1)
                }
                TextButton {
                    visible: panel.users.length > 1
                    text: "\u{f0142}"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: panel.pickUser(1)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            // Password
            Row {
                width: parent.width
                height: 32
                spacing: 10
                leftPadding: 6

                Text {
                    text: panel.busy ? "\u{f0996}" : Theme.lockIcon
                    font.family: Theme.font
                    font.pixelSize: 16
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: password
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: "#ffffff"
                    selectionColor: "#ffffff"
                    selectedTextColor: "#000000"
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    cursorVisible: !panel.busy
                    readOnly: panel.busy || panel.launching
                    focus: true

                    Text {
                        visible: password.text === ""
                        text: panel.busy ? "Checking…" : "Password"
                        font: password.font
                        color: Theme.dim
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.submit();
                        else if (event.key === Qt.Key_Up) panel.pickUser(-1);
                        else if (event.key === Qt.Key_Down) panel.pickUser(1);
                        else if (event.key === Qt.Key_Escape) password.text = "";
                        else return;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    // Glitch in at start, out before the session starts
    GlitchReveal {
        id: reveal
        x: box.x
        y: box.y
        width: box.width
        height: box.height
        content: box
        onClosed: {
            box.visible = false;
            fadeOut.start();
        }
    }

    // Status line + power buttons
    Column {
        id: footer
        x: panel.shakeRoom + 6
        anchors.top: box.bottom
        anchors.topMargin: 14
        width: box.width - 12
        spacing: 10

        Text {
            width: parent.width
            visible: text !== ""
            text: panel.message
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.dim
            wrapMode: Text.Wrap
        }

        Row {
            spacing: 16

            TextButton {
                text: "\u{f0709}  reboot"
                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
            }
            TextButton {
                text: "\u{f0425}  power off"
                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }
    }
}
