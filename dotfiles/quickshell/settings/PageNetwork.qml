import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property bool wifiOn: true
    property string selectedSsid: ""
    property string password: ""
    property string statusText: "Scanning..."
    property string connectedSsid: ""
    property bool passwordMode: false
    property bool connecting: false
    property bool connectFailed: false
    property bool rescanning: false
    property bool showPassword: false

    readonly property color statusColor:
        !page.wifiOn
        ? Theme.mutedColor
        : page.connecting
          ? Theme.warnColor
          : page.connectFailed
            ? Theme.badColor
            : page.rescanning
              ? Theme.accentColor
              : page.connectedSsid !== ""
                ? Theme.goodColor
                : Theme.mutedColor

    onPasswordModeChanged: Theme.typing = page.passwordMode

    Component.onDestruction: Theme.typing = false

    readonly property bool hasHero: true

    Binding {
        target: Theme
        property: "stateColor"
        value: page.statusColor
    }

    ListModel {
        id: networkModel
    }

    function signalIcon(s) {
        if (s >= 80)
            return "\uDB82\uDD28"

        if (s >= 60)
            return "\uDB82\uDD25"

        if (s >= 40)
            return "\uDB82\uDD22"

        if (s >= 20)
            return "\uDB82\uDD1F"

        return "\uDB82\uDD2F"
    }

    function signalColor(s) {
        if (s >= 75)
            return Theme.goodColor

        if (s >= 50)
            return Theme.infoColor

        if (s >= 30)
            return Theme.warnColor

        return Theme.badColor
    }

    function isOpen(security) {
        return security === "" || security === "--"
    }

    function scan(rescan) {
        if (scanProc.running)
            return

        page.rescanning = rescan

        if (rescan)
            page.statusText = "Scanning..."

        scanProc.command = rescan
            ? ["python3", Theme.netScript, "list", "rescan"]
            : ["python3", Theme.netScript, "list"]

        scanProc.running = true
    }

    function parseNetworks(data) {
        var lines = data.split("\n")
        var result = []
        var seen = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            if (!line)
                continue

            var c1 = line.indexOf(":")
            var c2 = line.indexOf(":", c1 + 1)
            var c3 = line.indexOf(":", c2 + 1)

            if (c1 < 0 || c2 < 0 || c3 < 0)
                continue

            var active = line.substring(0, c1) === "yes"
            var strength = Number(line.substring(c1 + 1, c2))
            var security = line.substring(c2 + 1, c3)
            var ssid = line.substring(c3 + 1).replace(/\\:/g, ":").replace(/\\\\/g, "\\")

            if (!ssid)
                continue

            if (seen[ssid] !== undefined) {
                var e = result[seen[ssid]]
                e.strength = Math.max(e.strength, strength)
                e.active = e.active || active
                continue
            }

            seen[ssid] = result.length
            result.push({ ssid: ssid, strength: strength, security: security, active: active })
        }

        result.sort(function(a, b) {
            if (a.active && !b.active)
                return -1

            if (!a.active && b.active)
                return 1

            return b.strength - a.strength
        })

        syncModel(result)

        var connected = ""

        for (var n = 0; n < result.length; n++) {
            if (result[n].active) {
                connected = result[n].ssid
                break
            }
        }

        page.connectedSsid = connected
        page.rescanning = false

        if (!page.connecting && !page.connectFailed) {
            if (!page.wifiOn)
                page.statusText = "Wi-Fi is off"
            else if (result.length === 0)
                page.statusText = "No networks found"
            else if (connected !== "")
                page.statusText = "Connected to " + connected
            else
                page.statusText = "Not connected"
        }
    }

    function syncModel(result) {
        var same = networkModel.count === result.length

        if (same) {
            for (var i = 0; i < result.length; i++) {
                if (networkModel.get(i).ssid !== result[i].ssid) {
                    same = false
                    break
                }
            }
        }

        if (same) {
            for (var j = 0; j < result.length; j++)
                networkModel.set(j, result[j])

            return
        }

        networkModel.clear()

        for (var k = 0; k < result.length; k++)
            networkModel.append(result[k])
    }

    function selectNetwork(ssid, security, active) {
        if (page.connecting || active)
            return

        page.selectedSsid = ssid

        if (page.isOpen(security)) {
            page.connecting = true
            page.connectFailed = false
            page.statusText = "Connecting..."
            connectProc.command = ["python3", Theme.netScript, "connect", ssid]
            connectProc.running = true
            return
        }

        page.connectFailed = false
        page.showPassword = false
        page.password = ""
        passwordField.text = ""
        page.passwordMode = true

        Qt.callLater(function() {
            passwordField.forceActiveFocus()
        })
    }

    function cancelPassword() {
        page.passwordMode = false
        page.password = ""
        page.connectFailed = false
        page.showPassword = false
        page.forceActiveFocus()
    }

    function connectWithPassword() {
        if (!page.selectedSsid || !page.password || page.connecting)
            return

        page.connecting = true
        page.connectFailed = false
        page.statusText = "Connecting..."

        connectProc.pw = page.password
        connectProc.command = ["python3", Theme.netScript, "connect-pw", page.selectedSsid]
        connectProc.running = true
    }

    function checkState() {
        if (!stateProc.running)
            stateProc.running = true
    }

    Row {
        id: topRow

        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        spacing: 10

        Btn {
            width: 40
            height: 40
            iconSize: 21
            filled: page.wifiOn
            icon: page.wifiOn ? "\uDB81\uDDA9" : "\uDB81\uDDAA"
            tone: page.statusColor

            onClicked: toggleProc.running = true
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 114
            spacing: 2

            Lbl {
                text: "WI-FI"
                color: Theme.titleColor
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Lbl {
                width: parent.width
                text: page.statusText
                color: page.statusColor
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Btn {
            id: refreshBtn

            width: 54
            height: 40
            icon: "\uDB81\uDC50"
            tone: page.rescanning ? Theme.accentColor : Theme.textColor
            enabled: page.wifiOn

            onClicked: page.scan(true)
        }
    }

    Rectangle {
        id: line

        anchors.top: topRow.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 1
        color: Theme.tint(page.statusColor, 0.35)
    }

    Head {
        id: head

        anchors.top: line.bottom
        anchors.topMargin: 8
        width: parent.width
        title: "AVAILABLE NETWORKS"
        info: networkModel.count
    }

    ListView {
        id: networkList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom

        model: networkModel
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded

            contentItem: Rectangle {
                implicitWidth: 3
                radius: 2
                visible: parent && parent.size < 1
                color: Theme.accentColor
                opacity: 0.55
            }
        }

        delegate: Card {
            id: net

            required property string ssid
            required property int strength
            required property string security
            required property bool active

            readonly property bool isConnecting: page.connecting && page.selectedSsid === net.ssid

            readonly property color stateColor:
                net.active
                ? Theme.goodColor
                : net.isConnecting
                  ? Theme.warnColor
                  : page.signalColor(net.strength)

            width: networkList.width
            height: 54
            clickable: true
            selected: net.active || net.isConnecting
            tone: net.stateColor

            onClicked: page.selectNetwork(net.ssid, net.security, net.active)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                width: 3
                radius: 2
                color: net.stateColor
            }

            Rectangle {
                id: iconTile

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 4
                color: Theme.tint(net.stateColor, 0.16)

                Lbl {
                    anchors.centerIn: parent
                    text: page.signalIcon(net.strength)
                    color: net.stateColor
                    font.pixelSize: 18
                }
            }

            Column {
                anchors.left: iconTile.right
                anchors.leftMargin: 10
                anchors.right: rightInfo.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Lbl {
                    width: parent.width
                    text: net.ssid
                    color: Theme.titleColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Lbl {
                    width: parent.width
                    font.pixelSize: 9
                    font.weight: Font.DemiBold

                    text: net.active
                          ? "Connected"
                          : net.isConnecting
                            ? "Connecting..."
                            : page.isOpen(net.security)
                              ? "Open network"
                              : "Secured"

                    color: net.active
                           ? Theme.goodColor
                           : net.isConnecting
                             ? Theme.warnColor
                             : page.isOpen(net.security)
                               ? Theme.warnColor
                               : Theme.infoColor
                }
            }

            Row {
                id: rightInfo

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: net.active
                    text: "\uDB80\uDD2C"
                    color: Theme.goodColor
                    font.pixelSize: 14
                }

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !net.active && !page.isOpen(net.security)
                    text: "\uDB80\uDF3E"
                    color: Theme.infoColor
                    font.pixelSize: 12
                }

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    text: net.strength + "%"
                    color: page.signalColor(net.strength)
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Card {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        height: 84
        visible: networkModel.count === 0

        Column {
            anchors.centerIn: parent
            spacing: 6

            Lbl {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uDB81\uDDAA"
                color: page.rescanning ? Theme.accentColor : Theme.warnColor
                font.pixelSize: 22
            }

            Lbl {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.statusText
                color: page.rescanning ? Theme.accentColor : Theme.warnColor
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        id: overlay

        anchors.fill: parent
        anchors.margins: -4
        radius: 4
        visible: page.passwordMode
        color: Theme.tint(Theme.panelColor, 0.82)

        MouseArea {
            anchors.fill: parent

            onClicked: page.cancelPassword()
        }

        Card {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 380)
            height: 184
            color: Theme.panelColor
            border.width: 1
            border.color: page.connectFailed ? Theme.tint(Theme.badColor, 0.6) : Theme.lineColor

            MouseArea {
                anchors.fill: parent
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Row {
                    width: parent.width
                    height: 36
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 4
                        color: Theme.tint(Theme.accentColor, 0.16)

                        Lbl {
                            anchors.centerIn: parent
                            text: "\uDB80\uDF3E"
                            color: Theme.accentColor
                            font.pixelSize: 17
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 46
                        spacing: 3

                        Lbl {
                            text: "CONNECT TO WI-FI"
                            color: Theme.titleColor
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Lbl {
                            width: parent.width
                            text: page.selectedSsid
                            color: Theme.mutedColor
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 36

                    TextField {
                        id: passwordField

                        anchors.fill: parent
                        placeholderText: "Wi-Fi password"
                        echoMode: page.showPassword ? TextInput.Normal : TextInput.Password
                        color: Theme.titleColor
                        placeholderTextColor: Theme.mutedColor
                        selectionColor: Theme.accentColor
                        selectedTextColor: Theme.inkColor
                        font.family: Theme.fontName
                        font.pixelSize: 11
                        leftPadding: 10
                        rightPadding: 56
                        verticalAlignment: TextInput.AlignVCenter

                        background: Rectangle {
                            color: Theme.cardColor
                            radius: 4
                            border.width: page.connectFailed || passwordField.activeFocus ? 1 : 0
                            border.color: page.connectFailed ? Theme.badColor : Theme.accentColor
                        }

                        onTextChanged: {
                            page.password = text
                            page.connectFailed = false
                        }

                        Keys.onReturnPressed: page.connectWithPassword()
                        Keys.onEnterPressed: page.connectWithPassword()
                        Keys.onEscapePressed: page.cancelPassword()
                    }

                    Lbl {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.showPassword ? "HIDE" : "SHOW"
                        color: showMouse.containsMouse ? Theme.titleColor : Theme.mutedColor
                        font.pixelSize: 8
                        font.weight: Font.Bold

                        MouseArea {
                            id: showMouse

                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: page.showPassword = !page.showPassword
                        }
                    }
                }

                Lbl {
                    width: parent.width
                    height: 12
                    font.pixelSize: 9
                    font.weight: Font.DemiBold

                    text: page.connectFailed
                          ? "Wrong password or connection failed"
                          : page.connecting
                            ? "Connecting..."
                            : "Press Enter to connect"

                    color: page.connectFailed
                           ? Theme.badColor
                           : page.connecting
                             ? Theme.warnColor
                             : Theme.mutedColor
                }

                Row {
                    width: parent.width
                    height: 32
                    spacing: 8

                    Btn {
                        width: (parent.width - 8) / 2
                        label: "CANCEL"
                        tone: Theme.textColor

                        onClicked: page.cancelPassword()
                    }

                    Btn {
                        width: (parent.width - 8) / 2
                        label: page.connecting ? "CONNECTING..." : page.connectFailed ? "RETRY" : "CONNECT"
                        filled: true
                        enabled: !page.connecting && page.password !== ""
                        tone: page.connecting ? Theme.warnColor : page.connectFailed ? Theme.badColor : Theme.accentColor

                        onClicked: page.connectWithPassword()
                    }
                }
            }
        }
    }

    Process {
        id: scanProc

        command: []

        stdout: StdioCollector {
            onStreamFinished: page.parseNetworks(this.text)
        }
    }

    Process {
        id: stateProc

        command: ["python3", Theme.netScript, "state"]

        stdout: StdioCollector {
            onStreamFinished: {
                page.wifiOn = this.text.trim() !== "disabled"

                if (!page.wifiOn) {
                    page.statusText = "Wi-Fi is off"
                    page.connectedSsid = ""
                    networkModel.clear()
                }
            }
        }
    }

    Process {
        id: toggleProc

        command: ["python3", Theme.netScript, "toggle"]

        onExited: (exitCode) => {
            if (exitCode !== 0)
                return

            page.connectedSsid = ""
            page.connecting = false
            page.connectFailed = false
            page.statusText = "Updating..."
            page.rescanning = true
            toggleTimer.restart()
        }
    }

    Process {
        id: connectProc

        property string pw: ""

        command: []
        stdinEnabled: true

        onStarted: {
            if (connectProc.pw !== "") {
                connectProc.write(connectProc.pw + "\n")
                connectProc.pw = ""
            }
        }

        onExited: (exitCode) => {
            connectProc.pw = ""
            page.connecting = false

            if (exitCode === 0) {
                page.passwordMode = false
                page.password = ""
                page.connectFailed = false
                page.showPassword = false
                page.statusText = "Connected"
                page.forceActiveFocus()
                page.scan(true)
                return
            }

            page.connectFailed = true
            page.statusText = "Connection failed"

            if (!page.passwordMode)
                failTimer.restart()
        }
    }

    Timer {
        id: toggleTimer

        interval: 700

        onTriggered: {
            page.checkState()
            page.scan(true)
        }
    }

    Timer {
        id: failTimer

        interval: 3000

        onTriggered: {
            if (!page.passwordMode)
                page.connectFailed = false
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: true

        onTriggered: {
            if (page.wifiOn && !page.passwordMode) {
                page.checkState()
                page.scan(false)
            }
        }
    }

    Component.onCompleted: {
        page.checkState()
        page.scan(true)
    }
}
