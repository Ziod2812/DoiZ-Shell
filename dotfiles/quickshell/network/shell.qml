import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property real glassA: 1.0
    property color panelColor: Qt.rgba(basePanelColor.r, basePanelColor.g, basePanelColor.b, Math.min(basePanelColor.a, root.glassA))
    property color cardColor: Qt.rgba(baseCardColor.r, baseCardColor.g, baseCardColor.b, Math.min(baseCardColor.a, root.glassA))
    property color hoverColor: Qt.rgba(baseHoverColor.r, baseHoverColor.g, baseHoverColor.b, Math.min(baseHoverColor.a, root.glassA))
    property color activeCardColor: Qt.rgba(baseActiveCardColor.r, baseActiveCardColor.g, baseActiveCardColor.b, Math.min(baseActiveCardColor.a, root.glassA))

    FileView {
        id: doizGlassFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/mycfg/bar-glass"
        onLoaded: {
            var l = text().split("\n")
            var p = parseFloat(l[1])
            if (isNaN(p)) p = 50
            root.glassA = l[0].trim() === "on" ? Math.max(0.2, Math.min(1, p / 100)) : 1.0
        }
        onLoadFailed: root.glassA = 1.0
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: doizGlassFile.reload()
    }

    property bool shown: true

    property bool closing: false

    readonly property bool autoClose: false

    Timer {
        id: quitTimer

        interval: 250
        onTriggered: root.finishClose()
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            if (root.shown) {
                root.closePopup()
                return
            }

            root.shown = true
            root.refreshPopup()
        }

        function show(): void {
            root.shown = true
            root.refreshPopup()
        }

        function hide(): void {
            root.closePopup()
        }
    }

    property string selectedSsid: ""
    property string expandedSsid: ""
    property string password: ""
    property string statusText: "Scanning..."
    property bool passwordMode: false
    property bool connecting: false
    property bool connectFailed: false
    property bool rescanning: false
    property bool showPassword: false

    property color basePanelColor: "#f21b1d2d"
    property color baseCardColor: "#1a8e96ad"
    property color baseHoverColor: "#2e8e96ad"
    property color baseActiveCardColor: "#22b9d8c2"
    property color lineColor: "#40747e9d"
    property color titleColor: "#e8eaf3"
    property color textColor: "#c7ccda"
    property color mutedColor: "#8e96ad"
    property color accentColor: "#b59edc"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color connectedColor: "#b9d8c2"
    property color warningColor: "#e6c58a"
    property color dangerColor: "#e6a8b8"
    property color infoColor: "#9ec5e6"
    property color orangeColor: "#e6a988"
    property string fontName: "JetBrainsMono Nerd Font"
    property string connectedSsid: ""

    property color statusColor: root.connecting
                                ? root.warningColor
                                : root.connectFailed
                                  ? root.dangerColor
                                  : root.rescanning
                                    ? root.accentColor
                                    : root.connectedSsid !== ""
                                      ? root.connectedColor
                                      : root.mutedColor

    ListModel {
        id: networkModel
    }

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function themeColor(value, fallback) {
        var text = (value || "").trim()

        if (/^#[0-9a-fA-F]{6}$/.test(text))
            return text

        if (/^#[0-9a-fA-F]{8}$/.test(text))
            return text

        return fallback
    }

    function applyTheme(data) {
        var lines = data.split("\n")
        var colors = {}
        var inColors = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line === "[colors]") {
                inColors = true
                continue
            }

            if (line.indexOf("[") === 0 && line !== "[colors]") {
                inColors = false
                continue
            }

            if (!inColors)
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
                continue

            var key = line.substring(0, separator).trim()
            var value = line.substring(separator + 1).trim()

            colors[key] = value
        }

        root.basePanelColor = themeColor(
            colors["background"],
            "#1b1d2d"
        )

        root.baseCardColor = Qt.rgba(
            Qt.color(
                themeColor(
                    colors["surface"],
                    "#25283a"
                )
            ).r,
            Qt.color(
                themeColor(
                    colors["surface"],
                    "#25283a"
                )
            ).g,
            Qt.color(
                themeColor(
                    colors["surface"],
                    "#25283a"
                )
            ).b,
            0.58
        )

        root.baseHoverColor = Qt.rgba(
            Qt.color(
                themeColor(
                    colors["surface_alt"],
                    "#313244"
                )
            ).r,
            Qt.color(
                themeColor(
                    colors["surface_alt"],
                    "#313244"
                )
            ).g,
            Qt.color(
                themeColor(
                    colors["surface_alt"],
                    "#313244"
                )
            ).b,
            0.72
        )

        root.baseActiveCardColor = Qt.rgba(
            Qt.color(
                themeColor(
                    colors["accent"],
                    "#cba6f7"
                )
            ).r,
            Qt.color(
                themeColor(
                    colors["accent"],
                    "#cba6f7"
                )
            ).g,
            Qt.color(
                themeColor(
                    colors["accent"],
                    "#cba6f7"
                )
            ).b,
            0.13
        )

        root.lineColor = Qt.rgba(
            Qt.color(
                themeColor(
                    colors["muted"],
                    "#8e96ad"
                )
            ).r,
            Qt.color(
                themeColor(
                    colors["muted"],
                    "#8e96ad"
                )
            ).g,
            Qt.color(
                themeColor(
                    colors["muted"],
                    "#8e96ad"
                )
            ).b,
            0.25
        )

        root.titleColor = themeColor(
            colors["foreground"],
            "#e8eaf3"
        )

        root.textColor = themeColor(
            colors["foreground"],
            "#c7ccda"
        )

        root.mutedColor = themeColor(
            colors["muted"],
            "#8e96ad"
        )

        root.accentColor = themeColor(
            colors["accent_alt"] || colors["accent"],
            "#cba6f7"
        )

        root.connectedColor = themeColor(
            colors["green"],
            "#a6e3a1"
        )

        root.warningColor = themeColor(
            colors["yellow"],
            "#e6c58a"
        )

        root.dangerColor = themeColor(
            colors["red"],
            "#f38ba8"
        )

        root.infoColor = themeColor(
            colors["blue"],
            "#89b4fa"
        )

        root.orangeColor = themeColor(
            colors["yellow"],
            "#e6a988"
        )
    }

    function reloadTheme() {
        if (themeProcess.running)
            return

        themeProcess.running = true
    }

    function scanNetworks(rescan) {
        if (scanProcess.running)
            return

        root.rescanning = rescan

        if (rescan)
            root.statusText = "Scanning..."

        scanProcess.command = [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" list "
                + (rescan ? "rescan" : "")
                + " 2>/dev/null"
        ]

        scanProcess.running = true
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
            var ssid = line.substring(c3 + 1)
                .replace(/\\:/g, ":")
                .replace(/\\\\/g, "\\")

            if (!ssid)
                continue

            if (seen[ssid] !== undefined) {
                var existing = result[seen[ssid]]
                existing.strength = Math.max(
                    existing.strength,
                    strength
                )
                existing.active =
                    existing.active || active
                continue
            }

            seen[ssid] = result.length

            result.push({
                ssid: ssid,
                strength: strength,
                security: security,
                active: active
            })
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

        root.connectedSsid = connected
        root.rescanning = false

        if (!root.connecting && !root.connectFailed) {
            if (result.length === 0)
                root.statusText = "No networks found"
            else if (connected !== "")
                root.statusText = "Connected to " + connected
            else
                root.statusText = "Not connected"
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

    function isOpen(security) {
        return security === "" || security === "--"
    }

    function selectNetwork(ssid, security, active) {
        if (root.connecting)
            return

        root.selectedSsid = ssid

        root.expandedSsid = ""

        if (active) {
            root.statusText = "Connected"
            return
        }

        if (isOpen(security)) {
            connectOpenNetwork(ssid)
            return
        }

        openPassword()
    }

    function runAction(kind, ssid) {
        if (actionProcess.running)
            return

        root.expandedSsid = ""
        root.statusText = kind === "forget"
            ? "Forgetting..." : "Disconnecting..."

        actionProcess.command = [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" \"$1\" \"$2\"",
            "doiz-network",
            kind,
            ssid
        ]

        actionProcess.running = true
    }

    function openPassword() {
        root.connectFailed = false
        root.showPassword = false
        root.password = ""
        passwordField.text = ""
        root.passwordMode = true
        closeTimer.stop()

        Qt.callLater(function() {
            passwordField.forceActiveFocus()
        })
    }

    function cancelPassword() {
        root.passwordMode = false
        root.password = ""
        root.connectFailed = false
        root.showPassword = false
        closeTimer.restart()
    }

    function connectOpenNetwork(ssid) {
        root.connecting = true
        root.connectFailed = false
        root.statusText = "Connecting..."

        connectProcess.command = [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" connect \"$1\"",
            "doiz-network",
            ssid
        ]

        connectProcess.running = true
    }

    function connectPasswordNetwork() {
        if (!root.selectedSsid || !root.password || root.connecting)
            return

        root.connecting = true
        root.connectFailed = false
        root.statusText = "Connecting..."

        connectProcess.pw = root.password
        connectProcess.command = [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" connect-pw \"$1\"",
            "doiz-network",
            root.selectedSsid
        ]

        connectProcess.running = true
    }

    function refreshPopup() {
        root.quitPending = false
        root.reloadTheme()
        root.scanNetworks(true)
        closeTimer.restart()
    }

    property bool quitPending: false

    function closePopup() {
        if (root.closing)
            return

        root.closing = true
        quitTimer.start()
    }

    function finishClose() {
        root.shown = false

        if (root.connecting) {
            root.quitPending = true
            return
        }

        Qt.quit()
    }

    function signalIcon(strength) {
        if (strength >= 80)
            return "󰤨"

        if (strength >= 60)
            return "󰤥"

        if (strength >= 40)
            return "󰤢"

        if (strength >= 20)
            return "󰤟"

        return "󰤯"
    }

    function signalColor(strength) {
        if (strength >= 75)
            return root.connectedColor

        if (strength >= 50)
            return root.infoColor

        if (strength >= 30)
            return root.warningColor

        if (strength >= 15)
            return root.orangeColor

        return root.dangerColor
    }

    component GlowText: Text {
        id: gt

        property color glowColor: root.accentColor
        property bool blink: true
        property int period: 2400
        property int delay: 0
        property real minGlow: 0.25
        property real pulse: blink ? minGlow : 1

        opacity: blink ? 0.62 + 0.38 * pulse : 1

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: gt.glowColor
            shadowBlur: 1.0
            shadowOpacity: gt.pulse * 0.9
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        SequentialAnimation {
            running: gt.blink
            loops: Animation.Infinite

            PauseAnimation { duration: gt.delay }
            NumberAnimation { target: gt; property: "pulse"; to: 1; duration: gt.period / 2; easing.type: Easing.InOutSine }
            NumberAnimation { target: gt; property: "pulse"; to: gt.minGlow; duration: gt.period / 2; easing.type: Easing.InOutSine }
        }
    }

    PanelWindow {
        id: clickLayer

        visible: root.shown && !root.closing

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.namespace: "doiz-network-click"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closePopup()
            }
        }
    }

    PanelWindow {
        id: networkPanel

        visible: root.shown

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 8
        }

        implicitWidth: 330
        implicitHeight: Math.min(
            520,
            Math.max(
                280,
                122 + networkModel.count * 60
            )
        )

        color: "transparent"

        WlrLayershell.namespace: "doiz-network-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus:
            root.passwordMode
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Rectangle {
            id: panel
            property bool panelShown: false
            Component.onCompleted: panelShown = true
            opacity: (panelShown && !root.closing) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                y: (panelShown && !root.closing) ? 0 : 10
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: Qt.lighter(root.accentColor, 1.3)
                c3: root.accentColor
                c4: Qt.lighter(root.accentColor, 1.3)
                cycle: 9000
            }

            anchors.fill: parent

            color: root.panelColor
            radius: 12

            border.width: 1
            border.color:
                root.tint(
                    root.statusColor,
                    0.3
                )

            Behavior on border.color {
                ColorAnimation {
                    duration: 200
                }
            }

            NumberAnimation on opacity {
                from: 0
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }

            HoverHandler {
                id: panelHover

                onHoveredChanged: {
                    if (hovered)
                        closeTimer.stop()
                    else if (!root.passwordMode)
                        closeTimer.restart()
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Row {
                    width: parent.width
                    height: 44
                    spacing: 9

                    Rectangle {
                        id: wifiToggle

                        width: 44
                        height: 44
                        radius: 8

                        color:
                            wifiToggleMouse.containsMouse
                            ? root.hoverColor
                            : root.tint(
                                root.statusColor,
                                0.16
                            )

                        border.width: 1
                        border.color: root.tint(root.statusColor, 0.5)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        GlowText {
                            glowColor: root.statusColor
                            period: 2200
                            delay: 0
                            anchors.centerIn: parent

                            text:
                                root.connectedSsid !== "" ||
                                root.rescanning ||
                                root.connecting
                                ? "󰖩"
                                : "󰖪"

                            color: root.statusColor

                            font.family: root.fontName
                            font.pixelSize: 22
                        }

                        MouseArea {
                            id: wifiToggleMouse

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                wifiToggleProcess.running = true
                            }
                        }
                    }

                    Column {
                        width: parent.width - 106

                        anchors.verticalCenter:
                            parent.verticalCenter

                        spacing: 3

                        Text {
                            text: "WI-FI"

                            color: root.mutedColor

                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        Text {
                            width: parent.width

                            text: root.statusText

                            color: root.titleColor

                            font.family: root.fontName
                            font.pixelSize: 11
                            font.weight: Font.DemiBold

                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: refreshButton

                        width: 44
                        height: 44
                        radius: 8

                        color:
                            refreshMouse.containsMouse
                            ? root.hoverColor
                            : root.cardColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        GlowText {
                            glowColor: root.toneB
                            period: 2500
                            delay: 260
                            id: refreshIcon

                            anchors.centerIn: parent

                            text: "󰑐"

                            color:
                                root.rescanning
                                ? root.accentColor
                                : root.textColor

                            font.family: root.fontName
                            font.pixelSize: 18

                            NumberAnimation {
                                target: refreshIcon
                                property: "rotation"
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: root.rescanning

                                onRunningChanged: {
                                    if (!running)
                                        refreshIcon.rotation = 0
                                }
                            }
                        }

                        MouseArea {
                            id: refreshMouse

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                root.scanNetworks(true)
                                closeTimer.restart()
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1

                    color:
                        root.tint(
                            root.statusColor,
                            0.35
                        )

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: "AVAILABLE NETWORKS"

                        color: root.mutedColor

                        font.family: root.fontName
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: networkModel.count

                        color: root.accentColor

                        font.family: root.fontName
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 95

                    ListView {
                        id: networkList

                        anchors.fill: parent

                        model: networkModel
                        spacing: 6
                        clip: true
                        boundsBehavior:
                            Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 2

                                color: root.accentColor
                                opacity: 0.55
                            }
                        }

                        delegate: Rectangle {
                            id: card

                            width: networkList.width
                            height: 54 + extra
                            radius: 8
                            clip: true

                            property bool expanded:
                                model.active &&
                                root.expandedSsid === model.ssid

                            property string ssidValue: model.ssid

                            property real extra: expanded ? 42 : 0

                            Behavior on extra {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                            property bool isConnecting:
                                root.connecting &&
                                root.selectedSsid ===
                                model.ssid

                            property color stateColor:
                                model.active
                                ? root.connectedColor
                                : isConnecting
                                  ? root.warningColor
                                  : root.signalColor(
                                      model.strength
                                  )

                            color:
                                model.active ||
                                isConnecting
                                ? root.tint(
                                    stateColor,
                                    0.13
                                )
                                : cardMouse.containsMouse
                                  ? root.hoverColor
                                  : root.cardColor

                            border.width:
                                model.active ||
                                isConnecting
                                ? 1
                                : 0

                            border.color:
                                stateColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                anchors.leftMargin:
                                    model.active || card.isConnecting ? 3 : 0
                                anchors.topMargin: 12
                                anchors.bottomMargin: 12 + card.extra

                                width: 3
                                radius: 2

                                color: card.stateColor
                            }

                            Rectangle {
                                id: iconTile

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                anchors.verticalCenterOffset:
                                    -card.extra / 2

                                width: 34
                                height: 34
                                radius: 8

                                color:
                                    root.tint(
                                        card.stateColor,
                                        0.16
                                    )

                                Text {
                                    anchors.centerIn: parent

                                    text:
                                        root.signalIcon(
                                            model.strength
                                        )

                                    color: card.stateColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 18
                                }
                            }

                            Column {
                                anchors.left:
                                    iconTile.right

                                anchors.leftMargin: 10

                                anchors.right:
                                    rightInfo.left

                                anchors.rightMargin: 8

                                anchors.verticalCenter:
                                    parent.verticalCenter
                                anchors.verticalCenterOffset:
                                    -card.extra / 2

                                spacing: 3

                                Text {
                                    width: parent.width

                                    text: model.ssid

                                    color: root.titleColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 11
                                    font.weight:
                                        Font.DemiBold

                                    elide:
                                        Text.ElideRight
                                }

                                Text {
                                    width: parent.width

                                    text:
                                        model.active
                                        ? "Connected"
                                        : root.connecting &&
                                          root.selectedSsid ===
                                          model.ssid
                                          ? "Connecting..."
                                          : root.isOpen(
                                              model.security
                                            )
                                            ? "Open network"
                                            : "Secured"

                                    color:
                                        model.active
                                        ? root.connectedColor
                                        : card.isConnecting
                                          ? root.warningColor
                                          : root.isOpen(
                                              model.security
                                            )
                                            ? root.orangeColor
                                            : root.infoColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 9
                                    font.weight:
                                        Font.DemiBold

                                    elide:
                                        Text.ElideRight
                                }
                            }

                            Row {
                                id: rightInfo

                                anchors.right:
                                    parent.right

                                anchors.rightMargin: 12

                                anchors.verticalCenter:
                                    parent.verticalCenter
                                anchors.verticalCenterOffset:
                                    -card.extra / 2

                                spacing: 8

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    visible:
                                        model.active

                                    text: "󰄬"

                                    color:
                                        root.connectedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 14
                                }

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    visible:
                                        !model.active &&
                                        !root.isOpen(
                                            model.security
                                        )

                                    text: "󰌾"

                                    color:
                                        root.infoColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 12
                                }

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    text:
                                        model.strength + "%"

                                    color:
                                        root.signalColor(
                                            model.strength
                                        )

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 9
                                    font.weight:
                                        Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: cardMouse

                                anchors.fill: parent

                                hoverEnabled: true
                                cursorShape:
                                    Qt.PointingHandCursor

                                acceptedButtons:
                                    Qt.LeftButton | Qt.RightButton

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        if (model.active) {
                                            root.expandedSsid =
                                                root.expandedSsid === model.ssid
                                                ? "" : model.ssid
                                            closeTimer.restart()
                                        }
                                        return
                                    }

                                    root.selectNetwork(
                                        model.ssid,
                                        model.security,
                                        model.active
                                    )
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                anchors.bottomMargin: 8

                                visible: card.extra > 1
                                opacity: card.extra / 42
                                spacing: 8

                                Repeater {
                                    model: [
                                        { kind: "disconnect", label: "󰖪  Disconnect", warn: false },
                                        { kind: "forget", label: "󰆴  Forget", warn: true }
                                    ]

                                    delegate: Rectangle {
                                        id: actBtn

                                        required property var modelData

                                        width: (parent.width - 8) / 2
                                        height: 28
                                        radius: 7

                                        property color baseC:
                                            modelData.warn
                                            ? root.orangeColor
                                            : root.accentColor

                                        color: actMouse.containsMouse
                                            ? root.tint(baseC, 0.28)
                                            : root.tint(baseC, 0.14)

                                        border.width: 1
                                        border.color: root.tint(baseC, 0.5)

                                        Text {
                                            anchors.centerIn: parent
                                            text: actBtn.modelData.label
                                            color: actBtn.baseC
                                            font.family: root.fontName
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: actMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                root.runAction(
                                                    actBtn.modelData.kind,
                                                    card.ssidValue
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        height: 84
                        radius: 8

                        visible:
                            networkModel.count === 0

                        color: root.cardColor

                        Column {
                            anchors.centerIn: parent

                            spacing: 6

                            GlowText {
                                glowColor: root.toneB
                                period: 2800
                                delay: 520
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text: "󰖪"

                                color:
                                    root.rescanning
                                    ? root.accentColor
                                    : root.warningColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 22
                            }

                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text: root.statusText

                                color:
                                    root.rescanning
                                    ? root.accentColor
                                    : root.warningColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: passwordOverlay

                anchors.fill: parent

                radius: panel.radius

                visible: root.passwordMode

                color: "#cc101220"

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        root.cancelPassword()
                    }
                }

                Rectangle {
                    id: passwordCard

                    anchors.centerIn: parent

                    width: parent.width - 32
                    height: 184

                    radius: 8

                    color: root.panelColor

                    border.width: 1

                    border.color:
                        root.connectFailed
                        ? root.tint(
                            root.dangerColor,
                            0.6
                        )
                        : root.lineColor

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

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
                                radius: 8

                                color:
                                    root.tint(
                                        root.accentColor,
                                        0.12
                                    )

                                GlowText {
                                    glowColor: root.accentColor
                                    period: 3100
                                    delay: 780
                                    anchors.centerIn: parent

                                    text: "󰌾"

                                    color:
                                        root.accentColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 17
                                }
                            }

                            Column {
                                width: parent.width - 46

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing: 3

                                Text {
                                    text:
                                        "CONNECT TO WI-FI"

                                    color:
                                        root.titleColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 11
                                    font.weight:
                                        Font.Bold
                                }

                                Text {
                                    width: parent.width

                                    text:
                                        root.selectedSsid

                                    color:
                                        root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 9
                                    font.weight:
                                        Font.DemiBold

                                    elide:
                                        Text.ElideRight
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 36

                            TextField {
                                id: passwordField

                                anchors.fill: parent

                                placeholderText:
                                    "Wi-Fi password"

                                echoMode:
                                    root.showPassword
                                    ? TextInput.Normal
                                    : TextInput.Password

                                color: root.titleColor

                                placeholderTextColor:
                                    root.mutedColor

                                selectionColor:
                                    root.accentColor

                                selectedTextColor:
                                    "#171925"

                                font.family:
                                    root.fontName

                                font.pixelSize: 11

                                leftPadding: 10
                                rightPadding: 56

                                verticalAlignment:
                                    TextInput.AlignVCenter

                                background: Rectangle {
                                    color:
                                        root.cardColor

                                    radius: 8

                                    border.width:
                                        root.connectFailed ||
                                        passwordField.activeFocus
                                        ? 1
                                        : 0

                                    border.color:
                                        root.connectFailed
                                        ? root.dangerColor
                                        : root.accentColor
                                }

                                onTextChanged: {
                                    root.password = text
                                    root.connectFailed = false
                                }

                                Keys.onReturnPressed: {
                                    root.connectPasswordNetwork()
                                }

                                Keys.onEnterPressed: {
                                    root.connectPasswordNetwork()
                                }

                                Keys.onEscapePressed: {
                                    root.cancelPassword()
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    root.showPassword
                                    ? "HIDE"
                                    : "SHOW"

                                color:
                                    showMouse.containsMouse
                                    ? root.titleColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8
                                font.weight:
                                    Font.Bold

                                MouseArea {
                                    id: showMouse

                                    anchors.fill: parent
                                    anchors.margins: -6

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.showPassword =
                                            !root.showPassword
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            height: 12

                            text:
                                root.connectFailed
                                ? "Wrong password or connection failed"
                                : root.connecting
                                  ? "Connecting..."
                                  : "Press Enter to connect"

                            color:
                                root.connectFailed
                                ? root.dangerColor
                                : root.connecting
                                  ? root.warningColor
                                  : root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 9
                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
                        }

                        Row {
                            width: parent.width
                            height: 32
                            spacing: 8

                            Rectangle {
                                width:
                                    (parent.width - 8) / 2

                                height: 32
                                radius: 8

                                color:
                                    cancelMouse.containsMouse
                                    ? root.hoverColor
                                    : root.cardColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "CANCEL"

                                    color:
                                        root.textColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 9
                                    font.weight:
                                        Font.Bold
                                }

                                MouseArea {
                                    id: cancelMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.cancelPassword()
                                    }
                                }
                            }

                            Rectangle {
                                width:
                                    (parent.width - 8) / 2

                                height: 32
                                radius: 8

                                color:
                                    root.connecting
                                    ? root.warningColor
                                    : root.connectFailed
                                      ? root.dangerColor
                                      : root.accentColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                opacity:
                                    root.connecting ||
                                    root.password === ""
                                    ? 0.45
                                    : connectMouse.containsMouse
                                      ? 0.9
                                      : 1

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text:
                                        root.connecting
                                        ? "CONNECTING..."
                                        : root.connectFailed
                                          ? "RETRY"
                                          : "CONNECT"

                                    color: "#171925"

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 9
                                    font.weight:
                                        Font.Bold
                                }

                                MouseArea {
                                    id: connectMouse

                                    anchors.fill: parent

                                    enabled:
                                        !root.connecting

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.connectPasswordNetwork()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: themeProcess

        command: [
            "bash",
            "-c",
            "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/theme/theme.conf\" 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.applyTheme(this.text)
            }
        }
    }

    Process {
        id: scanProcess

        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseNetworks(this.text)
            }
        }
    }

    Process {
        id: connectProcess

        property string pw: ""

        command: []
        stdinEnabled: true

        onStarted: {
            if (connectProcess.pw !== "") {
                connectProcess.write(connectProcess.pw + "\n")
                connectProcess.pw = ""
            }
        }

        onExited: function(exitCode, exitStatus) {
            connectProcess.pw = ""
            root.connecting = false

            if (root.quitPending) {
                Qt.quit()
                return
            }

            if (exitCode === 0) {
                root.passwordMode = false
                root.password = ""
                root.connectFailed = false
                root.showPassword = false
                root.statusText = "Connected"
                root.scanNetworks(true)
                closeTimer.restart()
                return
            }

            root.connectFailed = true
            root.statusText = "Connection failed"

            if (!root.passwordMode) {
                failTimer.restart()
                closeTimer.restart()
            }
        }
    }

    Process {
        id: actionProcess

        command: []

        onExited: function(exitCode, exitStatus) {
            root.connectedSsid = ""
            root.connectFailed = exitCode !== 0
            root.statusText = exitCode === 0 ? "Updating..." : "Action failed"
            root.scanNetworks(true)
            closeTimer.restart()
        }
    }

    Process {
        id: wifiToggleProcess

        command: [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" toggle"
        ]

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                return

            root.connectedSsid = ""
            root.connecting = false
            root.connectFailed = false
            root.statusText = "Updating..."
            root.rescanning = true

            wifiRefreshTimer.restart()
        }
    }

    Timer {
        id: wifiRefreshTimer

        interval: 700
        repeat: false

        onTriggered: {
            root.scanNetworks(true)
        }
    }

    Timer {
        id: failTimer

        interval: 3000
        repeat: false

        onTriggered: {
            if (!root.passwordMode)
                root.connectFailed = false
        }
    }

    Timer {
        id: closeTimer

        interval: 5000
        repeat: false
        running: true

        onTriggered: {
            if (root.autoClose && !root.passwordMode &&
                !panelHover.hovered) {
                root.closePopup()
            }
        }
    }

    Timer {
        id: refreshTimer

        interval: 4000
        repeat: true
        running: true

        onTriggered: {
            root.reloadTheme()
            root.scanNetworks(false)
        }
    }

    Component.onCompleted: {
        root.reloadTheme()
        root.scanNetworks(true)
    }
}