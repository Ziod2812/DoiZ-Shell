import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property real barX: -1
    readonly property real barScrW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920

    function readBarAnchor(t) {
        var p = String(t).trim().split(/\s+/)
        var x = parseFloat(p[0])
        var ts = parseFloat(p[1])
        root.barX = (!isNaN(x) && !isNaN(ts) && Date.now() - ts < 2500) ? x : -1
    }

    function popX(w, fallback) {
        if (root.barX < 0)
            return fallback
        return Math.max(8, Math.min(root.barScrW - w - 8, root.barX - w / 2))
    }

    FileView {
        id: barAnchor

        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/doiz-bar-anchor"
        blockLoading: true
        onLoaded: root.readBarAnchor(barAnchor.text())
        onLoadFailed: root.barX = -1
    }

    property real glassA: 1.0
    property color panelColor: Qt.rgba(basePanelColor.r, basePanelColor.g, basePanelColor.b, Math.min(basePanelColor.a, root.glassA))
    property color cardColor: Qt.rgba(baseCardColor.r, baseCardColor.g, baseCardColor.b, Math.min(baseCardColor.a, root.glassA))
    property color trackColor: Qt.rgba(baseTrackColor.r, baseTrackColor.g, baseTrackColor.b, Math.min(baseTrackColor.a, root.glassA))

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

    property bool opened: false
    property bool closing: false

    Timer {
        interval: 30
        running: true
        onTriggered: root.opened = true
    }

    IpcHandler {
        target: "sysinfo"

        function toggle(): void {
            barAnchor.reload()
            if (Date.now() - root.lastCleared < 400)
                return

            if (root.shown && !root.closing)
                root.closePopup()
            else
                root.showPopup()
        }

        function show(): void {
            barAnchor.reload()
            root.showPopup()
        }

        function hide(): void {
            root.closePopup()
        }
    }

    readonly property var scr: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: root.scr ? root.scr.width : 1920
    readonly property real screenX: root.scr ? root.scr.x : 0
    readonly property real screenY: root.scr ? root.scr.y : 0
    property real barBottom: 40
    readonly property real popupW: 324
    readonly property real popupH: contentColumn.implicitHeight + 24
    readonly property real popLeft: root.popX(root.popupW, Math.max(8, (root.screenW - root.popupW) / 2))
    readonly property real popTop: root.barBottom

    property real curX: -1
    property real curY: -1
    property bool seen: false
    property real lastCleared: 0

    readonly property bool inPopup:
        root.curY >= root.popTop - 4 && root.curY <= root.popTop + root.popupH + 6
        && root.curX >= root.popLeft - 4 && root.curX <= root.popLeft + root.popupW + 4

    readonly property bool inBar: root.curY >= 0 && root.curY <= root.barBottom
    readonly property bool inside: root.inBar || root.inPopup

    onInsideChanged: {
        if (!root.shown)
            return

        if (root.inside) {
            root.seen = true
            closeTimer.stop()
        }
    }

    property real beat: 0.15

    SequentialAnimation {
        running: root.shown
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "beat"; to: 1; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "beat"; to: 0.15; duration: 1100; easing.type: Easing.InOutSine }
    }

    function showPopup() {
        root.seen = false
        root.closing = false
        quitTimer.stop()
        root.shown = true
        root.loadTheme()
        root.loadStats()
        graceTimer.restart()
    }

    property string themeFile:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/theme/theme.conf"

    property color basePanelColor: "#f21b1d2d"
    property color baseCardColor: "#1a8e96ad"
    property color baseTrackColor: "#338e96ad"
    property color lineColor: "#40747e9d"
    property color titleColor: "#e8eaf3"
    property color textColor: "#c7ccda"
    property color mutedColor: "#8e96ad"
    property color accentColor: "#b59edc"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color chargingColor: "#b9d8c2"
    property color infoColor: "#9ec5e6"
    property color warningColor: "#e6c58a"
    property color orangeColor: "#e6a988"
    property color dangerColor: "#e6a8b8"
    property string fontName: "JetBrainsMono Nerd Font"

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function parseTheme(data) {
        var lines = data.split("\n")
        var section = ""
        var colors = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line)
                continue

            if (line.charAt(0) === "[") {
                section =
                    line.substring(
                        1,
                        line.length - 1
                    )
                continue
            }

            if (section !== "colors")
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
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

            colors[key] = value
        }

        if (colors["background"])
            root.basePanelColor =
                Qt.rgba(
                    parseInt(
                        colors["background"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["background"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["background"].substring(5, 7),
                        16
                    ) / 255,
                    0.95
                )

        if (colors["surface"])
            root.baseCardColor =
                Qt.rgba(
                    parseInt(
                        colors["surface"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface"].substring(5, 7),
                        16
                    ) / 255,
                    0.62
                )

        if (colors["surface_alt"])
            root.baseTrackColor =
                Qt.rgba(
                    parseInt(
                        colors["surface_alt"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface_alt"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface_alt"].substring(5, 7),
                        16
                    ) / 255,
                    0.35
                )

        if (colors["foreground"])
            root.titleColor =
                colors["foreground"]

        if (colors["subtext"])
            root.textColor =
                colors["subtext"]

        if (colors["muted"])
            root.mutedColor =
                colors["muted"]

        if (colors["accent"])
            root.accentColor =
                (colors["accent_alt"] || colors["accent"])

        if (colors["green"])
            root.chargingColor =
                colors["green"]

        if (colors["blue"])
            root.infoColor =
                colors["blue"]

        if (colors["yellow"])
            root.warningColor =
                colors["yellow"]

        if (colors["orange"])
            root.orangeColor =
                colors["yellow"]

        if (colors["red"])
            root.dangerColor =
                colors["red"]

        if (colors["accent"])
            root.lineColor =
                Qt.rgba(
                    parseInt(
                        colors["accent"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["accent"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["accent"].substring(5, 7),
                        16
                    ) / 255,
                    0.25
                )
    }

    property real cpuUsage: 0
    property string cpuName: "CPU"
    property string cpuFreq: "--"
    property real cpuTemp: -1
    property int cpuCores: 0

    property string gpuName: "GPU"
    property bool gpuFound: false
    property real gpuUsage: -1
    property real gpuTemp: -1
    property real vramUsed: -1
    property real vramTotal: -1
    property string gpuFreq: ""
    property bool gpuShared: false

    property real ramUsed: 0
    property real ramTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    property real maxTemp: Math.max(root.cpuTemp, root.gpuTemp)

    function tempColor(t) {
        if (t < 0) return root.mutedColor
        if (t >= 85) return root.dangerColor
        if (t >= 75) return root.orangeColor
        if (t >= 60) return root.warningColor
        return root.chargingColor
    }

    function loadColor(p) {
        if (p < 0) return root.mutedColor
        if (p >= 90) return root.dangerColor
        if (p >= 70) return root.orangeColor
        if (p >= 45) return root.warningColor
        return root.chargingColor
    }

    function gb(kb) {
        return (kb / 1048576).toFixed(1) + " GB"
    }

    function mb(m) {
        return m >= 1024 ? (m / 1024).toFixed(1) + " GB" : Math.round(m) + " MB"
    }

    function tempText(t) {
        return t < 0 ? "--" : Math.round(t) + "°C"
    }

    function pctText(p) {
        return p < 0 ? "--" : Math.round(p) + "%"
    }

    function loadStats() {
        if (!statsProcess.running)
            statsProcess.running = true
    }

    function loadTheme() {
        if (!themeProcess.running)
            themeProcess.running = true
    }

    function parseStats(data) {
        var lines = data.split("\n")
        var m = {}

        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].indexOf("=")
            if (p > 0)
                m[lines[i].substring(0, p)] = lines[i].substring(p + 1).trim()
        }

        function num(k, d) {
            var v = parseFloat(m[k])
            return isNaN(v) ? d : v
        }

        root.cpuUsage = num("CPU", 0)
        root.cpuName = m["CPU_NAME"] || "CPU"
        root.cpuFreq = m["CPU_FREQ"] || "--"
        root.cpuCores = num("CPU_CORES", 0)
        root.cpuTemp = num("CPU_TEMP", -1)

        root.gpuFound = m["GPU_FOUND"] === "1"
        root.gpuName = m["GPU_NAME"] || "GPU"
        root.gpuUsage = num("GPU_USAGE", -1)
        root.gpuTemp = num("GPU_TEMP", -1)
        root.vramUsed = num("VRAM_USED", -1)
        root.vramTotal = num("VRAM_TOTAL", -1)
        root.gpuFreq = m["GPU_FREQ"] || ""
        root.gpuShared = m["GPU_SHARED"] === "1"

        root.ramTotal = num("RAM_TOTAL", 0)
        root.ramUsed = num("RAM_USED", 0)
        root.swapTotal = num("SWAP_TOTAL", 0)
        root.swapUsed = num("SWAP_USED", 0)
    }

    function closePopup() {
        if (!root.shown || root.closing)
            return

        root.closing = true
        closeTimer.stop()
        graceTimer.stop()
        quitTimer.restart()
    }

    component StatLine: Item {
        property string label: ""
        property string value: ""
        property color valueColor: root.textColor
        property bool blink: false

        width: parent.width
        height: 14

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: root.mutedColor
            font.family: root.fontName
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: parent.valueColor
            opacity: parent.blink ? 0.55 + 0.45 * root.beat : 1
            font.family: root.fontName
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    component StatCard: Rectangle {
        id: sc

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property real percent: 0
        property string bigText: ""
        property color tone: root.accentColor
        default property alias rows: rowsColumn.data

        width: parent.width
        height: rowsColumn.children.length > 0 ? 58 + rowsColumn.implicitHeight + 12 : 58
        radius: 10
        color: root.cardColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 12
            width: 3
            height: 28
            radius: 2
            color: sc.tone
            opacity: 0.55 + 0.45 * root.beat

            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: sc.tone
                shadowBlur: 1.0
                shadowOpacity: root.beat * 0.9
            }
        }

        Rectangle {
            id: tile
            x: 12
            y: 8
            width: 34
            height: 34
            radius: 8
            color: root.tint(sc.tone, 0.16)

            GlowText {
                anchors.centerIn: parent
                glowColor: sc.tone
                period: 2600
                text: sc.icon
                color: sc.tone
                font.family: root.fontName
                font.pixelSize: 18
            }
        }

        Column {
            anchors.left: tile.right
            anchors.leftMargin: 10
            anchors.right: big.left
            anchors.rightMargin: 8
            y: 9
            spacing: 2

            Text {
                width: parent.width
                text: sc.title
                color: root.mutedColor
                font.family: root.fontName
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1
            }

            Text {
                width: parent.width
                text: sc.subtitle
                color: root.titleColor
                font.family: root.fontName
                font.pixelSize: 10
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        GlowText {
            id: big
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 10
            glowColor: sc.tone
            period: sc.percent >= 90 ? 900 : sc.percent >= 70 ? 1500 : 2800
            minGlow: sc.percent >= 70 ? 0.2 : 0.4
            text: sc.bigText
            color: sc.tone
            font.family: root.fontName
            font.pixelSize: 16
            font.weight: Font.Bold
        }

        Rectangle {
            id: track
            x: 12
            y: 46
            width: parent.width - 24
            height: 4
            radius: 2
            color: root.trackColor

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, sc.percent / 100))
                height: parent.height
                radius: 2
                color: sc.tone
                opacity: 0.7 + 0.3 * root.beat

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: sc.tone
                    shadowBlur: 1.0
                    shadowOpacity: root.beat * 0.85
                }

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        Column {
            id: rowsColumn
            x: 12
            y: 58
            width: parent.width - 24
            spacing: 4
        }
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

    HyprlandFocusGrab {
        windows: [ sysPanel ]
        active: root.shown && !root.closing

        onCleared: {
            root.lastCleared = Date.now()
            root.closePopup()
        }
    }

    PanelWindow {
        id: sysPanel

        screen: root.scr
        visible: root.shown || card.opacity > 0.01

        anchors {
            top: true
            left: true
        }

        margins {
            top: root.popTop - 12
            left: root.popLeft
        }

        exclusionMode: ExclusionMode.Ignore

        implicitWidth: root.popupW
        implicitHeight: root.popupH + 22

        color: "transparent"

        WlrLayershell.namespace: "doiz-sysinfo"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card

            width: root.popupW
            height: root.popupH
            y: (root.opened && !root.closing) ? 12 : 2
            radius: 12

            color: root.panelColor
            opacity: (root.opened && !root.closing) ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            readonly property bool hot: root.maxTemp >= 75

            border.width: 1
            border.color: root.tint(
                root.tempColor(root.maxTemp),
                hot ? 0.3 + 0.45 * root.beat : 0.35
            )

            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: Qt.lighter(root.accentColor, 1.3)
                c3: root.accentColor
                c4: Qt.lighter(root.accentColor, 1.3)
                cycle: 9000
            }

            Column {
                id: contentColumn

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Item {
                    width: parent.width
                    height: 40

                    Rectangle {
                        id: headTile
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 8
                        color: root.tint(root.tempColor(root.maxTemp), 0.16)

                        GlowText {
                            anchors.centerIn: parent
                            glowColor: root.tempColor(root.maxTemp)
                            period: 2200
                            text: "\uf2db"
                            color: root.tempColor(root.maxTemp)
                            font.family: root.fontName
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        anchors.left: headTile.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "SYSTEM"
                            color: root.mutedColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }

                        GlowText {
                            glowColor: root.tempColor(root.maxTemp)
                            blink: root.maxTemp >= 0
                            period: root.maxTemp >= 85 ? 800 : root.maxTemp >= 75 ? 1400 : 3200
                            minGlow: root.maxTemp >= 75 ? 0.15 : 0.45
                            text: "Hottest " + root.tempText(root.maxTemp)
                            color: root.titleColor
                            font.family: root.fontName
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.lineColor
                }

                StatCard {
                    icon: "\uf2db"
                    title: "CPU"
                    subtitle: root.cpuName
                    percent: root.cpuUsage
                    bigText: root.pctText(root.cpuUsage)
                    tone: root.loadColor(root.cpuUsage)

                    StatLine { label: "Temperature"; value: root.tempText(root.cpuTemp); valueColor: root.tempColor(root.cpuTemp); blink: root.cpuTemp >= 75 }
                    StatLine { label: "Frequency"; value: root.cpuFreq }
                    StatLine { label: "Threads"; value: root.cpuCores > 0 ? String(root.cpuCores) : "--" }
                }

                StatCard {
                    icon: "\uf108"
                    title: "GPU"
                    subtitle: root.gpuFound ? root.gpuName : "No GPU sensor found"
                    percent: root.gpuUsage < 0 ? 0 : root.gpuUsage
                    bigText: root.pctText(root.gpuUsage)
                    tone: root.loadColor(root.gpuUsage)

                    StatLine { label: "Temperature"; value: root.tempText(root.gpuTemp); valueColor: root.tempColor(root.gpuTemp); blink: root.gpuTemp >= 75 }
                    StatLine {
                        visible: root.gpuFreq !== ""
                        height: visible ? 14 : 0
                        label: "Frequency"
                        value: root.gpuFreq
                    }
                    StatLine {
                        label: "VRAM"
                        value: root.gpuShared
                               ? "Shared with RAM"
                               : root.vramTotal > 0
                                 ? root.mb(root.vramUsed) + " / " + root.mb(root.vramTotal)
                                 : "--"
                    }
                }

                StatCard {
                    icon: "\udb80\udf5b"
                    title: "MEMORY"
                    subtitle: root.gb(root.ramUsed) + " / " + root.gb(root.ramTotal)
                    percent: root.ramTotal > 0 ? root.ramUsed * 100 / root.ramTotal : 0
                    bigText: root.ramTotal > 0 ? Math.round(root.ramUsed * 100 / root.ramTotal) + "%" : "--"
                    tone: root.loadColor(root.ramTotal > 0 ? root.ramUsed * 100 / root.ramTotal : -1)

                    StatLine {
                        label: "Swap"
                        value: root.swapTotal > 0
                               ? root.gb(root.swapUsed) + " / " + root.gb(root.swapTotal)
                               : "none"
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.loadStats()
    }

    Timer {
        id: closeTimer

        interval: 350
        onTriggered: root.closePopup()
    }

    Timer {
        id: graceTimer

        interval: 4000
        running: true
        onTriggered: {}
    }

    Timer {
        id: quitTimer

        interval: 250
        onTriggered: Qt.quit()
    }

    Process {
        id: cursorProc

        command: ["hyprctl", "-j", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text)

                    root.curX = o.x - root.screenX
                    root.curY = o.y - root.screenY
                } catch (e) {
                    root.curY = -1
                }
            }
        }
    }

    Timer {
        interval: 90
        repeat: true
        running: root.shown
        triggeredOnStart: true

        onTriggered: {
            if (!cursorProc.running)
                cursorProc.running = true
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.loadTheme()
    }

    Process {
        id: themeProcess

        command: [
            "sh", "-c",
            "if [ -f \"$1\" ]; then cat \"$1\"; fi",
            "doiz",
            root.themeFile
        ]

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    Process {
        id: statsProcess

        command: [
            "bash",
            Qt.resolvedUrl("stats.sh").toString().replace("file://", "")
        ]

        stdout: StdioCollector {
            onStreamFinished: root.parseStats(this.text)
        }
    }

    Component.onCompleted: {
        root.loadTheme()
        root.loadStats()
    }
}
