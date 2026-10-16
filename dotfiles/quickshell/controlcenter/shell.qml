import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
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

    anchors {
        top: true
        right: true
    }

    margins {
        top: 42
        right: 8
    }

    property int panelTopMargin: 42
    property int panelBottomMargin: 8
    property int collapsedHeight: 914

    implicitWidth: 330
    readonly property real fullHeight: root.screen
        ? Math.max(root.collapsedHeight, root.screen.height - root.panelTopMargin - root.panelBottomMargin)
        : root.collapsedHeight

    readonly property real panelTargetHeight: (notificationModel.count > 0 || root.clearingNotifications)
        ? root.fullHeight
        : root.collapsedHeight

    implicitHeight: root.fullHeight

    mask: Region {
        item: panel
    }
    color: "transparent"

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            Qt.quit()
        }

        function hide(): void {
            Qt.quit()
        }
    }

    WlrLayershell.namespace: "doiz_control_center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    property bool wifiEnabled: true
    property bool bluetoothEnabled: false
    property bool dndEnabled: false
    property bool darkMode: true
    property bool barGlass: false

    property real volume: 55
    property real brightness: 70
    property string mediaArtist: "No media"
    property string mediaTitle: "Nothing playing"
    property bool mediaPlaying: false
    property string mediaArtUrl: ""
    property real mediaPosition: 0
    property real mediaLength: 0
    property string cpuText: "--"
    property string ramText: "--"
    property string diskText: "--"
    property string uptimeText: "--"

    property color basePanelColor: "#12141f"
    property color baseCardColor: "#1f2231"
    property color baseHoverColor: "#313445"
    property color baseActiveCardColor: "#2e2940"
    property color lineColor: "#485066"

    property color titleColor: "#ebeffa"
    property color textColor: "#cdd3e6"
    property color mutedColor: "#8e96ad"

    property color accentColor: "#cba6f7"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)

    property real beat: 0.15

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "beat"; to: 1; duration: 1300; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "beat"; to: 0.15; duration: 1300; easing.type: Easing.InOutSine }
    }

    component PulseText: Text {
        id: pt

        property color glowColor: root.accentColor
        property bool live: true

        opacity: pt.live ? 0.65 + 0.35 * root.beat : 1

        layer.enabled: pt.live
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: pt.glowColor
            shadowBlur: 1.0
            shadowOpacity: root.beat * 0.9
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
    property color connectedColor: "#a6e3a1"
    property color warningColor: "#e6c58a"
    property color dangerColor: "#f38ba8"
    property color infoColor: "#cba6f7"
    property color accentTextColor: "#cba6f7"
    property color orangeColor: "#e6a988"

    property string fontName: "JetBrainsMono Nerd Font"

    property string themeFile:
        (Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")) +
        "/theme/theme.conf"

    property string lastThemeData: ""

    property string darkModeScript:
        (Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")) +
        "/hypr/scripts/dark-mode.sh"

    property string barGlassScript:
        (Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")) +
        "/theme/scripts/bar-glass.py"

    property int notificationLimit: 8
    property bool clearingNotifications: false
    property var dismissedIds: ({})

    ListModel {
        id: notificationModel
    }

    readonly property var notifdCmd: ["qs", "-c", "notifd", "ipc", "call", "notifd"]

    function notifdCall(args) {
        Quickshell.execDetached(root.notifdCmd.concat(args))
    }

    function removeNotification(notifId) {
        root.dismissedIds[String(notifId)] = true
        root.notifdCall(["dismiss", String(notifId)])

        for (var i = 0; i < notificationModel.count; i++) {
            if (notificationModel.get(i).notifId === notifId) {
                notificationModel.remove(i)
                break
            }
        }
    }

    function clearAllNotifications() {
        if (root.clearingNotifications || notificationModel.count === 0)
            return

        for (var i = 0; i < notificationModel.count; i++)
            root.dismissedIds[String(notificationModel.get(i).notifId)] = true

        root.notifdCall(["clear"])
        clearNotificationsTimer.interval = Math.min(notificationModel.count, 11) * 32 + 240
        root.clearingNotifications = true
        clearNotificationsTimer.restart()
    }

    function openNotification(notifId) {
        root.notifdCall(["invoke", String(notifId)])
    }

    function applyNotifications(text) {
        var list = []

        try {
            list = JSON.parse(text.trim() || "[]")
        } catch (e) {
            return
        }

        if (root.clearingNotifications)
            return

        var present = {}

        for (var d = 0; d < list.length; d++)
            present[String(list[d].id)] = true

        for (var key in root.dismissedIds) {
            if (!present[key])
                delete root.dismissedIds[key]
        }

        list = list.filter(function(it) {
            return !root.dismissedIds[String(it.id)]
        })

        var same = list.length === notificationModel.count

        for (var i = 0; same && i < list.length; i++)
            same = notificationModel.get(i).notifId === list[i].id

        if (same)
            return

        notificationModel.clear()

        for (var j = 0; j < list.length; j++) {
            notificationModel.append({
                notifId: list[j].id,
                appNameText: list[j].app,
                appIconSource: list[j].icon,
                titleText: list[j].title,
                bodyText: list[j].body,
                timeText: list[j].time
            })
        }
    }

    Process {
        id: notifListProcess

        command: root.notifdCmd.concat(["list"])

        stdout: StdioCollector {
            onStreamFinished: root.applyNotifications(this.text)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!notifListProcess.running)
                notifListProcess.running = true
        }
    }

    function formatTime(seconds) {
        var total = Math.max(0, Math.floor(seconds || 0))
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var sec = total % 60
        var ss = (sec < 10 ? "0" : "") + sec

        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss

        return m + ":" + ss
    }

    function tint(c, alpha) {
        return Qt.rgba(
            c.r,
            c.g,
            c.b,
            alpha
        )
    }

    function parseHex(value, fallback) {
        var text = String(value || "").trim()

        if (/^#[0-9a-fA-F]{6}$/.test(text))
            return text

        if (/^#[0-9a-fA-F]{8}$/.test(text))
            return text

        return fallback
    }

    function applyTheme(data) {
        if (!data || data.trim().length === 0)
            return

        if (data === root.lastThemeData)
            return

        root.lastThemeData = data

        var lines = data.split(/\r?\n/)
        var colors = {}
        var inColors = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line || line.indexOf("#") === 0)
                continue

            if (line === "[colors]") {
                inColors = true
                continue
            }

            if (
                line.indexOf("[") === 0 &&
                line !== "[colors]"
            ) {
                inColors = false
                continue
            }

            if (!inColors)
                continue

            var separator = line.indexOf("=")

            if (separator === -1)
                continue

            var key =
                line.substring(
                    0,
                    separator
                ).trim()

            var value =
                line.substring(
                    separator + 1
                ).trim()

            if (value.indexOf("#") === 0) {
                var comment =
                    value.indexOf(" ")

                if (comment !== -1)
                    value =
                        value.substring(
                            0,
                            comment
                        ).trim()
            }

            colors[key] = value
        }

        var backgroundHex =
            parseHex(
                colors["background"],
                "#12141f"
            )

        var surfaceHex =
            parseHex(
                colors["surface"],
                "#1f2231"
            )

        var surfaceAltHex =
            parseHex(
                colors["surface_alt"],
                "#313445"
            )

        var accentHex =
            parseHex(
                colors["accent"],
                "#cba6f7"
            )

        var foregroundHex =
            parseHex(
                colors["foreground"],
                "#ebeffa"
            )

        var subtextHex =
            parseHex(
                colors["subtext"],
                "#cdd3e6"
            )

        var mutedHex =
            parseHex(
                colors["muted"],
                "#8e96ad"
            )

        var greenHex =
            parseHex(
                colors["green"],
                "#a6e3a1"
            )

        var yellowHex =
            parseHex(
                colors["yellow"],
                "#e6c58a"
            )

        var redHex =
            parseHex(
                colors["red"],
                "#f38ba8"
            )

        panelColor =
            Qt.rgba(
                Qt.color(backgroundHex).r,
                Qt.color(backgroundHex).g,
                Qt.color(backgroundHex).b,
                0.94
            )

        cardColor =
            Qt.rgba(
                Qt.color(surfaceHex).r,
                Qt.color(surfaceHex).g,
                Qt.color(surfaceHex).b,
                0.78
            )

        hoverColor =
            Qt.rgba(
                Qt.color(surfaceAltHex).r,
                Qt.color(surfaceAltHex).g,
                Qt.color(surfaceAltHex).b,
                0.88
            )

        accentColor =
            Qt.color(accentHex)

        activeCardColor =
            Qt.rgba(
                accentColor.r,
                accentColor.g,
                accentColor.b,
                0.18
            )

        lineColor =
            Qt.rgba(
                accentColor.r,
                accentColor.g,
                accentColor.b,
                0.25
            )

        titleColor =
            Qt.color(foregroundHex)

        textColor =
            Qt.color(subtextHex)

        mutedColor =
            Qt.color(mutedHex)

        connectedColor =
            Qt.color(greenHex)

        warningColor =
            Qt.color(yellowHex)

        dangerColor =
            Qt.color(redHex)

        infoColor =
            accentColor

        var fgc = Qt.color(foregroundHex)
        accentTextColor =
            Qt.rgba(
                accentColor.r * 0.35 + fgc.r * 0.65,
                accentColor.g * 0.35 + fgc.g * 0.65,
                accentColor.b * 0.35 + fgc.b * 0.65,
                1
            )

        orangeColor =
            Qt.color(yellowHex)
    }

    Process {
        id: themeProcess

        command: [
            "bash",
            "-c",
            "cat -- \"" +
            root.themeFile +
            "\" 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.applyTheme(this.text)
            }
        }
    }

    Timer {
        id: themeTimer

        interval: 1500
        repeat: true
        running: true

        onTriggered: {
            if (!themeProcess.running)
                themeProcess.running = true
        }
    }

    Process {
        id: wifiStateProcess

        command: [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" state"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled =
                    this.text.trim() === "enabled"
            }
        }
    }

    Process {
        id: wifiProcess

        command: [
            "bash",
            "-c",
            "python3 \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/network/iwd.py\" toggle"
        ]

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                wifiStateProcess.running = true
        }
    }

    Process {
        id: bluetoothStateProcess

        command: [
            "bash",
            "-c",
            "systemctl is-active bluetooth"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothEnabled =
                    this.text.trim() === "active"
            }
        }
    }

    Process {
        id: bluetoothProcess

        command: [
            "bash",
            "-c",
            "if systemctl is-active --quiet bluetooth; then systemctl stop bluetooth; else systemctl start bluetooth; fi"
        ]

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                bluetoothStateProcess.running = true
        }
    }

    Process {
        id: dndStateProcess

        command: [
            "sh",
            "-c",
            "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/mycfg/dnd\" 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    root.dndEnabled = this.text.trim() === "1"
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!dndStateProcess.running)
                dndStateProcess.running = true
        }
    }

    Process {
        id: darkStateProcess

        command: [
            "bash",
            root.darkModeScript,
            "status"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.darkMode =
                    this.text.trim() !== "light"
            }
        }
    }

    Process {
        id: darkProcess

        command: [
            "bash",
            root.darkModeScript,
            "toggle"
        ]

        onExited: function(exitCode, exitStatus) {
            darkStateProcess.running = true
        }
    }

    Process {
        id: barGlassStateProcess

        command: [
            "python3",
            root.barGlassScript,
            "status"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.barGlass =
                    this.text.trim() === "on"
            }
        }
    }

    Process {
        id: barGlassProcess

        command: [
            "python3",
            root.barGlassScript,
            "toggle"
        ]

        onExited: function(exitCode, exitStatus) {
            barGlassStateProcess.running = true
        }
    }

    Process {
        id: volumeProcess

        command: [
            "bash",
            "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var match =
                    this.text.match(
                        /Volume:\s+([0-9.]+)/
                    )

                if (match) {
                    root.volume =
                        Math.round(
                            parseFloat(
                                match[1]
                            ) * 100
                        )
                }
            }
        }
    }

    Process {
        id: setVolumeProcess
    }

    Process {
        id: brightnessProcess

        command: [
            "bash",
            "-c",
            "brightnessctl -m"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var match =
                    this.text.match(
                        /,([0-9]+)%/
                    )

                if (match) {
                    root.brightness =
                        parseInt(match[1])
                }
            }
        }
    }

    Process {
        id: setBrightnessProcess
    }

    Process {
        id: mediaProcess

        command: [
            "bash",
            "-c",
            "playerctl metadata --format '{{artist}}|{{title}}|{{status}}|{{position}}|{{mpris:length}}|{{mpris:artUrl}}' 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")

                if (parts.length >= 6) {
                    var art = parts[parts.length - 1].trim()
                    var length = (Number(parts[parts.length - 2]) || 0) / 1000000
                    var position = (Number(parts[parts.length - 3]) || 0) / 1000000

                    root.mediaArtist = parts[0] || "Unknown artist"
                    root.mediaTitle =
                        parts.slice(1, parts.length - 4).join("|") || "Unknown title"
                    root.mediaPlaying =
                        parts[parts.length - 4].trim() === "Playing"

                    root.mediaLength = length

                    if (!mediaSlider.pressed)
                        root.mediaPosition = Math.min(position, length > 0 ? length : position)

                    root.mediaArtUrl =
                        /^(file|https?):\/\//.test(art) ? art : ""
                } else {
                    root.mediaArtist = "No media"
                    root.mediaTitle = "Nothing playing"
                    root.mediaPlaying = false
                    root.mediaArtUrl = ""
                    root.mediaPosition = 0
                    root.mediaLength = 0
                }
            }
        }
    }

    Process {
        id: systemInfoProcess

        command: [
            "bash",
            "-c",
            "cpu=$(top -bn1 | awk '/Cpu\\(s\\)/ {print int($2+$4)}'); ram=$(free -m | awk '/Mem:/ {printf \"%d%%\", ($3/$2)*100}'); disk=$(df -h / | awk 'NR==2 {print $5}'); up=$(uptime -p 2>/dev/null | sed -E 's/^up //; s/ years?/y/; s/ months?/mo/; s/ weeks?/w/; s/ days?/d/; s/ hours?/h/; s/ minutes?/m/; s/, //g'); printf '%s|%s|%s|%s' \"$cpu\" \"$ram\" \"$disk\" \"$up\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")

                if (parts.length >= 4) {
                    root.cpuText = parts[0] + "%"
                    root.ramText = parts[1]
                    root.diskText = parts[2]
                    root.uptimeText = parts[3]
                }
            }
        }
    }

    Timer {
        id: mediaTimer

        interval: 2000
        repeat: true
        running: true

        onTriggered: {
            if (!mediaProcess.running)
                mediaProcess.running = true

            if (!systemInfoProcess.running)
                systemInfoProcess.running = true
        }
    }

    Rectangle {
        id: panel
        property bool panelShown: false
        Component.onCompleted: panelShown = true
        opacity: panelShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        transform: Translate {
            y: panelShown ? 0 : 10
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

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        height: root.panelTargetHeight

        Behavior on height {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        radius: 12

        color:
            root.panelColor

        border.width: 1

        border.color:
            root.tint(
                root.accentColor,
                0.38
            )

        HoverHandler {
            id: panelHover

            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop()
                else
                    closeTimer.restart()
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            Row {
                width: parent.width
                height: 44
                spacing: 9

                Rectangle {
                    width: 44
                    height: 44
                    radius: 8

                    color:
                        root.tint(
                            root.accentColor,
                            0.18
                        )

                    PulseText {
                        anchors.centerIn: parent

                        text: "󰒓"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 22
                    }
                }

                Column {
                    width:
                        parent.width - 106

                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing: 3

                    Text {
                        text: "CONTROL CENTER"

                        color:
                            root.titleColor

                        font.family:
                            root.fontName

                        font.pixelSize: 12

                        font.weight:
                            Font.Bold
                    }

                    Text {
                        width: parent.width

                        text: "DoiZ system controls"

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

                Rectangle {
                    width: 44
                    height: 44
                    radius: 8

                    color:
                        closeMouse.containsMouse
                        ? root.hoverColor
                        : root.cardColor

                    Text {
                        anchors.centerIn: parent

                        text: "󰅖"

                        color:
                            root.textColor

                        font.family:
                            root.fontName

                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: closeMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            Qt.quit()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 2
                radius: 1

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.3; color: root.accentColor }
                    GradientStop { position: 0.6; color: root.toneB }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Text {
                width: parent.width
                height: 18

                text: "QUICK TOGGLES"

                color:
                    root.mutedColor

                font.family:
                    root.fontName

                font.pixelSize: 9

                font.weight:
                    Font.Bold

                verticalAlignment:
                    Text.AlignVCenter
            }

            GridLayout {
                width: parent.width

                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 8

                    color:
                        wifiToggle.containsMouse
                        ? root.hoverColor
                        : root.wifiEnabled
                            ? root.activeCardColor
                            : root.cardColor

                    border.width:
                        root.wifiEnabled ? 1 : 0

                    border.color:
                        root.accentColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9

                        Rectangle {
                            width: 36
                            height: 36

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius: 4

                            color:
                                root.tint(
                                    root.connectedColor,
                                    0.18
                                )

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.wifiEnabled
                                    ? "󰖩"
                                    : "󰖪"

                                color:
                                    root.wifiEnabled
                                    ? root.connectedColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 3

                            Text {
                                text:
                                    root.wifiEnabled
                                    ? "Wi-Fi"
                                    : "Wi-Fi Off"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.wifiEnabled
                                    ? "Enabled"
                                    : "Disabled"

                                color:
                                    root.wifiEnabled
                                    ? root.connectedColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8

                                font.weight:
                                    Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: wifiToggle

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            wifiProcess.running = true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 8

                    color:
                        bluetoothToggle.containsMouse
                        ? root.hoverColor
                        : root.bluetoothEnabled
                            ? root.activeCardColor
                            : root.cardColor

                    border.width:
                        root.bluetoothEnabled ? 1 : 0

                    border.color:
                        root.accentColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9

                        Rectangle {
                            width: 36
                            height: 36

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius: 4

                            color:
                                root.tint(
                                    root.accentColor,
                                    0.18
                                )

                            Text {
                                anchors.centerIn: parent

                                text: "󰂯"

                                color:
                                    root.accentTextColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 3

                            Text {
                                text:
                                    root.bluetoothEnabled
                                    ? "Bluetooth"
                                    : "Bluetooth Off"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.bluetoothEnabled
                                    ? "Enabled"
                                    : "Disabled"

                                color:
                                    root.bluetoothEnabled
                                    ? root.connectedColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8

                                font.weight:
                                    Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: bluetoothToggle

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            bluetoothProcess.running = true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 8

                    color:
                        dndToggle.containsMouse
                        ? root.hoverColor
                        : root.dndEnabled
                            ? root.activeCardColor
                            : root.cardColor

                    border.width:
                        root.dndEnabled ? 1 : 0

                    border.color:
                        root.accentColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9

                        Rectangle {
                            width: 36
                            height: 36

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius: 4

                            color:
                                root.tint(
                                    root.warningColor,
                                    0.18
                                )

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.dndEnabled
                                    ? "󰂚"
                                    : "󰂛"

                                color:
                                    root.warningColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 3

                            Text {
                                text:
                                    root.dndEnabled
                                    ? "Do Not Disturb"
                                    : "Notifications"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.dndEnabled
                                    ? "Muted"
                                    : "Enabled"

                                color:
                                    root.accentColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8

                                font.weight:
                                    Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: dndToggle

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.dndEnabled =
                                !root.dndEnabled

                            Quickshell.execDetached(
                                [
                                    "sh",
                                    "-c",
                                    "mkdir -p \"${XDG_CONFIG_HOME:-$HOME/.config}/mycfg\"; printf %s \"$1\" > \"${XDG_CONFIG_HOME:-$HOME/.config}/mycfg/dnd\"",
                                    "doiz",
                                    root.dndEnabled ? "1" : "0"
                                ]
                            )
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 8

                    color:
                        darkToggle.containsMouse
                        ? root.hoverColor
                        : root.darkMode
                            ? root.activeCardColor
                            : root.cardColor

                    border.width:
                        root.darkMode ? 1 : 0

                    border.color:
                        root.accentColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9

                        Rectangle {
                            width: 36
                            height: 36

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius: 4

                            color:
                                root.tint(
                                    root.accentColor,
                                    0.18
                                )

                            Text {
                                anchors.centerIn: parent

                                text:
                                    root.darkMode
                                    ? "󰖔"
                                    : "󰖙"

                                color:
                                    root.accentTextColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 3

                            Text {
                                text: "Dark Mode"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.darkMode
                                    ? "Enabled"
                                    : "Disabled (Light)"

                                color:
                                    root.darkMode
                                    ? root.connectedColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8

                                font.weight:
                                    Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: darkToggle

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            if (!darkProcess.running)
                                darkProcess.running = true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.preferredHeight: 62
                    radius: 8

                    color:
                        barGlassToggle.containsMouse
                        ? root.hoverColor
                        : root.barGlass
                            ? root.activeCardColor
                            : root.cardColor

                    border.width:
                        root.barGlass ? 1 : 0

                    border.color:
                        root.accentColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9

                        Rectangle {
                            width: 36
                            height: 36

                            anchors.verticalCenter:
                                parent.verticalCenter

                            radius: 4

                            color:
                                root.tint(
                                    root.accentColor,
                                    0.18
                                )

                            Text {
                                anchors.centerIn: parent

                                text: "󰂵"

                                color:
                                    root.accentTextColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 3

                            Text {
                                text: "Glass Mode"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.barGlass
                                    ? "On"
                                    : "Off"

                                color:
                                    root.barGlass
                                    ? root.connectedColor
                                    : root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8

                                font.weight:
                                    Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: barGlassToggle

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            if (!barGlassProcess.running)
                                barGlassProcess.running = true
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            Column {
                width: parent.width
                spacing: 5

                Row {
                    width: parent.width
                    height: 20
                    spacing: 8

                    Text {
                        width: 20

                        text: "󰕾"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 16

                        horizontalAlignment:
                            Text.AlignHCenter
                    }

                    Text {
                        width:
                            parent.width - 72

                        text: "VOLUME"

                        color:
                            root.titleColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.Bold
                    }

                    Text {
                        width: 44

                        text:
                            Math.round(
                                root.volume
                            ) + "%"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.DemiBold

                        horizontalAlignment:
                            Text.AlignRight
                    }
                }

                Slider {
                    id: volumeSlider

                    width: parent.width
                    height: 20

                    from: 0
                    to: 100
                    value: root.volume

                    onMoved: {
                        root.volume = value

                        setVolumeProcess.command = [
                            "bash",
                            "-c",
                            "wpctl set-volume @DEFAULT_AUDIO_SINK@ " +
                            (value / 100).toFixed(2)
                        ]

                        setVolumeProcess.running = true
                    }

                    background: Rectangle {
                        x:
                            parent.leftPadding

                        y:
                            parent.topPadding +
                            parent.availableHeight / 2 -
                            height / 2

                        width:
                            parent.availableWidth

                        height: 5
                        radius: 3

                        color:
                            root.cardColor

                        Rectangle {
                            width:
                                parent.width *
                                parent.parent.visualPosition

                            height:
                                parent.height

                            radius: 3

                            color:
                                root.accentColor
                        }
                    }

                    handle: Rectangle {
                        x:
                            parent.leftPadding +
                            parent.visualPosition *
                            (
                                parent.availableWidth -
                                width
                            )

                        y:
                            parent.topPadding +
                            parent.availableHeight / 2 -
                            height / 2

                        width: 11
                        height: 11
                        radius: 8

                        color:
                            root.accentColor

                        border.width: 1

                        border.color:
                            root.tint(
                                root.accentColor,
                                0.85
                            )
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 5

                Row {
                    width: parent.width
                    height: 20
                    spacing: 8

                    Text {
                        width: 20

                        text: "󰃠"

                        color:
                            root.warningColor

                        font.family:
                            root.fontName

                        font.pixelSize: 16

                        horizontalAlignment:
                            Text.AlignHCenter
                    }

                    Text {
                        width:
                            parent.width - 72

                        text: "BRIGHTNESS"

                        color:
                            root.titleColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.Bold
                    }

                    Text {
                        width: 44

                        text:
                            Math.round(
                                root.brightness
                            ) + "%"

                        color:
                            root.accentColor

                        font.family:
                            root.fontName

                        font.pixelSize: 9

                        font.weight:
                            Font.DemiBold

                        horizontalAlignment:
                            Text.AlignRight
                    }
                }

                Slider {
                    id: brightnessSlider

                    width: parent.width
                    height: 20

                    from: 0
                    to: 100
                    value: root.brightness

                    onMoved: {
                        root.brightness = value

                        setBrightnessProcess.command = [
                            "bash",
                            "-c",
                            "brightnessctl set " +
                            Math.round(value) +
                            "%"
                        ]

                        setBrightnessProcess.running = true
                    }

                    background: Rectangle {
                        x:
                            parent.leftPadding

                        y:
                            parent.topPadding +
                            parent.availableHeight / 2 -
                            height / 2

                        width:
                            parent.availableWidth

                        height: 5
                        radius: 3

                        color:
                            root.cardColor

                        Rectangle {
                            width:
                                parent.width *
                                parent.parent.visualPosition

                            height:
                                parent.height

                            radius: 3

                            color:
                                root.accentColor
                        }
                    }

                    handle: Rectangle {
                        x:
                            parent.leftPadding +
                            parent.visualPosition *
                            (
                                parent.availableWidth -
                                width
                            )

                        y:
                            parent.topPadding +
                            parent.availableHeight / 2 -
                            height / 2

                        width: 11
                        height: 11
                        radius: 8

                        color:
                            root.accentColor

                        border.width: 1

                        border.color:
                            root.tint(
                                root.accentColor,
                                0.85
                            )
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            Rectangle {
                width: parent.width
                height: 1

                color:
                    root.lineColor
            }

            Rectangle {
                width: parent.width
                height: 122
                radius: 8
                color: root.cardColor

                Row {
                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: 76
                    spacing: 10

                    Rectangle {
                        id: mediaThumb

                        width: parent.height
                        height: parent.height
                        radius: 4
                        clip: true
                        color: root.tint(root.accentColor, 0.12)

                        Image {
                            id: mediaArt

                            anchors.fill: parent
                            source: root.mediaArtUrl
                            opacity: root.glassA
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: 152
                            sourceSize.height: 152
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: mediaArt.status !== Image.Ready
                            text: "󰝚"
                            color: root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 26
                        }
                    }

                    Column {
                        width: parent.width - mediaThumb.width - parent.spacing
                        height: parent.height
                        spacing: 6

                        Row {
                            width: parent.width
                            height: 20
                            spacing: 8

                            PulseText {
                                live: root.mediaPlaying
                                text: "󰝚"
                                color: root.accentColor
                                font.family: root.fontName
                                font.pixelSize: 16
                            }

                            Text {
                                text: "MEDIA"
                                color: root.titleColor
                                font.family: root.fontName
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            PulseText {
                                live: root.mediaPlaying
                                glowColor: root.toneB
                                width: parent.width - 62
                                text: root.mediaArtist
                                color: root.mediaPlaying ? root.toneB : root.mutedColor
                                font.family: root.fontName
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            height: 14
                            text: root.mediaTitle
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Row {
                            width: parent.width
                            height: 30
                            spacing: 6

                            Rectangle {
                                width: (parent.width - 12) / 3
                                height: 30
                                radius: 8
                                color: mediaPrevMouse.containsMouse ? root.hoverColor : root.hoverColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: root.textColor
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: mediaPrevMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "previous"])
                                }
                            }

                            Rectangle {
                                width: (parent.width - 12) / 3
                                height: 30
                                radius: 8
                                color: mediaPlayMouse.containsMouse ? root.hoverColor : root.hoverColor

                                Text {
                                    anchors.centerIn: parent
                                    text: root.mediaPlaying ? "󰏤" : "󰐊"
                                    color: root.textColor
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: mediaPlayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.mediaPlaying = !root.mediaPlaying
                                        Quickshell.execDetached(["playerctl", "play-pause"])
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - 12) / 3
                                height: 30
                                radius: 8
                                color: mediaNextMouse.containsMouse ? root.hoverColor : root.hoverColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: root.textColor
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: mediaNextMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "next"])
                                }
                            }
                        }
                    }
                }

                Row {
                    x: 10
                    y: 94
                    width: parent.width - 20
                    height: 18
                    spacing: 6

                    Text {
                        width: 36
                        height: parent.height
                        text: root.formatTime(root.mediaPosition)
                        color: root.mutedColor
                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                    }

                    Slider {
                        id: mediaSlider

                        width: parent.width - 84
                        height: parent.height

                        from: 0
                        to: Math.max(1, root.mediaLength)
                        value: root.mediaPosition
                        enabled: root.mediaLength > 0

                        onPressedChanged: {
                            if (!pressed) {
                                root.mediaPosition = value

                                Quickshell.execDetached([
                                    "playerctl",
                                    "position",
                                    value.toFixed(2)
                                ])
                            }
                        }

                        background: Rectangle {
                            x: parent.leftPadding
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            width: parent.availableWidth
                            height: 5
                            radius: 3
                            color: root.hoverColor

                            Rectangle {
                                width: parent.width * parent.parent.visualPosition
                                height: parent.height
                                radius: 3
                                color: root.accentColor
                            }
                        }

                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            width: 11
                            height: 11
                            radius: 8
                            color: root.accentColor
                            border.width: 1
                            border.color: root.tint(root.accentColor, 0.85)
                        }
                    }

                    Text {
                        width: 36
                        height: parent.height
                        text: root.formatTime(root.mediaLength)
                        color: root.mutedColor
                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Row {
                width: parent.width
                height: 64
                spacing: 6

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 64
                    radius: 8
                    color: powerLockMouse.containsMouse ? root.hoverColor : root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰌾"
                            color: root.connectedColor
                            font.family: root.fontName
                            font.pixelSize: 18
                        }

                        Text {
                            text: "LOCK"
                            color: root.mutedColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: powerLockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["loginctl", "lock-session"])
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 64
                    radius: 8
                    color: powerLogoutMouse.containsMouse ? root.hoverColor : root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍃"
                            color: root.warningColor
                            font.family: root.fontName
                            font.pixelSize: 18
                        }

                        Text {
                            text: "LOGOUT"
                            color: root.mutedColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: powerLogoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 64
                    radius: 8
                    color: powerRebootMouse.containsMouse ? root.hoverColor : root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰜉"
                            color: root.infoColor
                            font.family: root.fontName
                            font.pixelSize: 18
                        }

                        Text {
                            text: "REBOOT"
                            color: root.mutedColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: powerRebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 64
                    radius: 8
                    color: powerShutdownMouse.containsMouse ? root.hoverColor : root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐥"
                            color: root.dangerColor
                            font.family: root.fontName
                            font.pixelSize: 18
                        }

                        Text {
                            text: "POWER OFF"
                            color: root.mutedColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: powerShutdownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.lineColor
            }

            Row {
                width: parent.width
                height: 62
                spacing: 6

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 62
                    radius: 8
                    color: root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍛"
                            color: root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 16
                        }

                        Text {
                            width: parent.width
                            text: "CPU " + root.cpuText
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 62
                    radius: 8
                    color: root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰘚"
                            color: root.connectedColor
                            font.family: root.fontName
                            font.pixelSize: 16
                        }

                        Text {
                            width: parent.width
                            text: "RAM " + root.ramText
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 62
                    radius: 8
                    color: root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰋊"
                            color: root.warningColor
                            font.family: root.fontName
                            font.pixelSize: 16
                        }

                        Text {
                            width: parent.width
                            text: "DISK " + root.diskText
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - 18) / 4
                    height: 62
                    radius: 8
                    color: root.cardColor

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width - 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰔠"
                            color: root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 16
                        }

                        Text {
                            width: parent.width
                            text: root.uptimeText
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 42
                spacing: 6

                Rectangle {
                    width:
                        (parent.width - 6) / 2

                    height: 42
                    radius: 8

                    color:
                        systemMouse.containsMouse
                        ? root.hoverColor
                        : root.cardColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 8

                        Text {
                            text: "󰒓"

                            color:
                                root.accentColor

                            font.family:
                                root.fontName

                            font.pixelSize: 17

                            anchors.verticalCenter:
                                parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 2

                            Text {
                                text: "SETTINGS"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 9

                                font.weight:
                                    Font.Bold
                            }

                            Text {
                                text: "System settings"

                                color:
                                    root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8
                            }
                        }
                    }

                    MouseArea {
                        id: systemMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            Quickshell.execDetached(
                                [
                                    "sh",
                                    "-c",
                                    "qs -c settings ipc call settings toggle || qs -c settings -n"
                                ]
                            )

                            Qt.quit()
                        }
                    }
                }

                Rectangle {
                    width:
                        (parent.width - 6) / 2

                    height: 42
                    radius: 8

                    color:
                        launcherMouse.containsMouse
                        ? root.hoverColor
                        : root.cardColor

                    Row {
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 8

                        Text {
                            text: "󰀻"

                            color:
                                root.accentColor

                            font.family:
                                root.fontName

                            font.pixelSize: 17

                            anchors.verticalCenter:
                                parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            spacing: 2

                            Text {
                                text: "LAUNCHER"

                                color:
                                    root.titleColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 9

                                font.weight:
                                    Font.Bold
                            }

                            Text {
                                text: "App launcher"

                                color:
                                    root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 8
                            }
                        }
                    }

                    MouseArea {
                        id: launcherMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            Quickshell.execDetached(
                                [
                                    "qs",
                                    "-c",
                                    "launcher",
                                    "--no-duplicate"
                                ]
                            )

                            Qt.quit()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.lineColor
            }

            Row {
                width: parent.width
                height: 22
                spacing: 8

                Text {
                    width: parent.width - 90
                    text: "NOTIFICATIONS"
                    color: root.mutedColor
                    font.family: root.fontName
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: 18
                    text: notificationModel.count
                    color: root.accentColor
                    font.family: root.fontName
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: 56
                    height: 22
                    radius: 4
                    color: clearNotificationsMouse.containsMouse
                           ? root.hoverColor
                           : root.cardColor

                    Text {
                        anchors.centerIn: parent
                        text: "CLEAR"
                        color: root.textColor
                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: clearNotificationsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAllNotifications()
                    }
                }
            }

            Rectangle {
                id: notificationCard

                readonly property real expandT: root.fullHeight > root.collapsedHeight
                    ? Math.max(0, Math.min(1, (panel.height - root.collapsedHeight) / (root.fullHeight - root.collapsedHeight)))
                    : 0

                width: parent.width
                height: 52 + expandT * (Math.max(52, parent.height - y) - 52)
                radius: 8
                color: root.cardColor

                ListView {
                    id: notificationList
                    anchors.fill: parent
                    anchors.margins: 6
                    model: notificationModel
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: 170
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                property: "x"
                                to: 36
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    delegate: Rectangle {
                        id: notifRow

                        property real outP: 0

                        opacity: 1 - outP
                        transform: Translate { x: notifRow.outP * 40 }

                        Connections {
                            target: root

                            function onClearingNotificationsChanged() {
                                if (root.clearingNotifications)
                                    rowClearAnim.start()
                            }
                        }

                        SequentialAnimation {
                            id: rowClearAnim

                            PauseAnimation {
                                duration: Math.min(index, 10) * 32
                            }

                            NumberAnimation {
                                target: notifRow
                                property: "outP"
                                from: 0
                                to: 1
                                duration: 190
                                easing.type: Easing.OutCubic
                            }
                        }

                        width: notificationList.width
                        height: 56
                        radius: 8
                        color: notificationMouse.containsMouse
                               ? root.hoverColor
                               : root.tint(root.accentColor, 0.07)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.tint(root.accentColor, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰂚"
                                    color: root.accentColor
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }
                            }

                            Column {
                                width: parent.width - 72
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Row {
                                    width: parent.width
                                    height: 13

                                    Text {
                                        width: parent.width - 42
                                        text: model.appNameText
                                        color: root.accentColor
                                        font.family: root.fontName
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: 42
                                        text: model.timeText
                                        color: root.mutedColor
                                        font.family: root.fontName
                                        font.pixelSize: 7
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: model.titleText
                                    color: root.titleColor
                                    font.family: root.fontName
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: model.bodyText
                                    color: root.textColor
                                    font.family: root.fontName
                                    font.pixelSize: 8
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: notificationMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.openNotification(model.notifId)
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.top: parent.top
                            anchors.topMargin: 6
                            color: dismissMouse.containsMouse
                                   ? root.hoverColor
                                   : root.tint(root.dangerColor, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: root.dangerColor
                                font.family: root.fontName
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeNotification(model.notifId)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notificationModel.count === 0
                    text: "No notifications"
                    color: root.mutedColor
                    font.family: root.fontName
                    font.pixelSize: 9
                }
            }
        }
    }

    Timer {
        id: clearNotificationsTimer

        interval: 500
        repeat: false

        onTriggered: {
            notificationModel.clear()
            root.clearingNotifications = false
        }
    }

    Timer {
        id: closeTimer

        interval: 5000
        repeat: true
        running: true

        onTriggered: {
            if (!panelHover.hovered)
                Qt.quit()
        }
    }

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]

        onActiveChanged: {
            if (!active)
                Qt.quit()
        }
    }

    Component.onCompleted: {
        themeProcess.running = true
        wifiStateProcess.running = true
        bluetoothStateProcess.running = true
        darkStateProcess.running = true
        barGlassStateProcess.running = true
        volumeProcess.running = true
        brightnessProcess.running = true
        mediaProcess.running = true
        systemInfoProcess.running = true

        focusGrab.active = true
    }
}
