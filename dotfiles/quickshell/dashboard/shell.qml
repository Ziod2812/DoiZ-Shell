import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string userName: Quickshell.env("USER") || "user"

    readonly property int panelW: 640
    readonly property int panelH: 360

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

    property bool closing: false
    property bool gpuMode: false
    property real wavePhase: 0

    Timer {
        interval: 33
        repeat: true
        running: !root.closing

        onTriggered: root.wavePhase += 0.09
    }

    function closePopup() {
        if (root.closing)
            return

        root.closing = true
        card.opacity = 0
        card.y = 0
        quitTimer.start()
    }

    Timer {
        id: quitTimer

        interval: 180
        onTriggered: Qt.quit()
    }

    property real pulse: 0

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulse"; to: 0; duration: 2200; easing.type: Easing.InOutSine }
    }

    IpcHandler {
        target: "popup"

        function close(): void {
            root.closePopup()
        }
    }

    property color panelColor: "#f51b1b1b"
    property color cardColor: "#942a2a2a"
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#8a8a8a"
    property color inkColor: "#1b1b1b"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function parseTheme(text) {
        var c = {}
        var inColors = false
        var lines = text.split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line === "[colors]") { inColors = true; continue }
            if (line.indexOf("[") === 0) { inColors = false; continue }

            var sep = line.indexOf("=")

            if (inColors && sep > 0)
                c[line.substring(0, sep).trim()] = line.substring(sep + 1).trim()
        }

        function pick(key, fb) {
            return /^#[0-9a-fA-F]{6}$/.test(c[key] || "") ? c[key] : fb
        }

        var bg = Qt.color(pick("background", "#1b1b1b"))
        var sf = Qt.color(pick("surface", "#2a2a2a"))
        var mu = Qt.color(pick("muted", "#777777"))

        root.panelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.96)
        root.cardColor = Qt.rgba(sf.r, sf.g, sf.b, 0.92)
        root.lineColor = Qt.rgba(mu.r, mu.g, mu.b, 0.3)
        root.inkColor = bg
        root.titleColor = pick("foreground", "#e0e0e0")
        root.textColor = pick("subtext", "#a8a8a8")
        root.mutedColor = pick("muted", "#777777")
        root.accentColor = pick("accent_alt", "#8a8a8a")
    }

    Process {
        command: ["sh", "-c", "cat \"$1/theme/theme.conf\" 2>/dev/null", "doiz", root.cfgHome]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property int todayY: clock.date.getFullYear()
    readonly property int todayM: clock.date.getMonth()
    readonly property int todayD: clock.date.getDate()
    readonly property var cells: calCells(root.viewYear, root.viewMonth)

    function calCells(y, m) {
        var offset = (new Date(y, m, 1).getDay() + 6) % 7
        var days = new Date(y, m + 1, 0).getDate()
        var rows = Math.ceil((offset + days) / 7)
        var out = []

        for (var i = 0; i < rows * 7; i++) {
            var d = i - offset + 1
            out.push({ d: d, cur: d >= 1 && d <= days })
        }

        return out
    }

    function shiftMonth(delta) {
        var m = root.viewMonth + delta
        var y = root.viewYear

        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }

        root.viewMonth = m
        root.viewYear = y
    }

    readonly property var player: {
        var ps = Mpris.players.values

        for (var i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                return ps[i]
        }

        return ps.length > 0 ? ps[0] : null
    }

    readonly property int barCount: 30
    property var levels: []

    function waveLevel(n) {
        var x = Math.max(0, Math.min(1, (n || 0) / 100))
        return 1 - Math.pow(1 - x, 2.0)
    }

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    Process {
        id: cavaProc

        running: true
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]

        stdout: SplitParser {
            onRead: data => {
                var p = data.split(";")
                var out = []

                for (var i = 0; i < p.length && out.length < root.barCount; i++) {
                    if (p[i] === "")
                        continue

                    var n = parseInt(p[i])
                    out.push(isNaN(n) ? 0 : Math.max(0, Math.min(100, n)))
                }

                if (out.length > 0)
                    root.levels = out
            }
        }
    }

    property int cpuP: 0
    property int memP: 0
    property string memGb: "0.0"
    property int rootP: 0
    property int bootP: -1
    property int homeP: 0
    property int gpuP: -1
    property int vramP: -1
    property string vramGb: "0.0"

    Process {
        id: statsProc

        command: ["bash", Quickshell.shellDir + "/stats.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var ls = this.text.split("\n")

                for (var i = 0; i < ls.length; i++) {
                    var kv = ls[i].split("=")

                    if (kv.length < 2)
                        continue

                    var v = parseFloat(kv[1])

                    if (kv[0] === "memgb") root.memGb = kv[1]
                    else if (kv[0] === "vramgb") root.vramGb = kv[1]
                    else if (isNaN(v)) continue
                    else if (kv[0] === "cpu") root.cpuP = v
                    else if (kv[0] === "mem") root.memP = v
                    else if (kv[0] === "root") root.rootP = v
                    else if (kv[0] === "boot") root.bootP = v
                    else if (kv[0] === "home") root.homeP = v
                    else if (kv[0] === "gpu") root.gpuP = v
                    else if (kv[0] === "vram") root.vramP = v
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true
        }
    }

    property string sysUptime: "--"
    property string sysKernel: "--"
    property string sysDesk: "--"

    Process {
        id: sysProc

        command: ["sh", "-c", "u=$(awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60); if(d>0) printf \"%dd %dh\",d,h; else if(h>0) printf \"%dh %dm\",h,m; else printf \"%dm\",m}' /proc/uptime); echo \"up=$u\"; echo \"kernel=$(uname -r | cut -d- -f1)\"; echo \"desk=${XDG_CURRENT_DESKTOP:-Hyprland}\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var ls = this.text.split("\n")

                for (var i = 0; i < ls.length; i++) {
                    var j = ls[i].indexOf("=")

                    if (j < 0)
                        continue

                    var k = ls[i].substring(0, j)
                    var v = ls[i].substring(j + 1)

                    if (k === "up") root.sysUptime = v
                    else if (k === "kernel") root.sysKernel = v
                    else if (k === "desk") root.sysDesk = v
                }
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            if (!sysProc.running)
                sysProc.running = true
        }
    }

    component GlowText: Text {
        id: gt

        property color glowColor: root.accentColor
        property bool blink: true
        property int period: 2400
        property int delay: 0
        property real minGlow: 0.25
        property real gp: blink ? minGlow : 1

        opacity: blink ? 0.62 + 0.38 * gp : 1

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: gt.glowColor
            shadowBlur: 1.0
            shadowOpacity: gt.gp * 0.9
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        SequentialAnimation {
            running: gt.blink
            loops: Animation.Infinite

            PauseAnimation { duration: gt.delay }
            NumberAnimation { target: gt; property: "gp"; to: 1; duration: gt.period / 2; easing.type: Easing.InOutSine }
            NumberAnimation { target: gt; property: "gp"; to: gt.minGlow; duration: gt.period / 2; easing.type: Easing.InOutSine }
        }
    }

    component NavBtn: Text {
        id: nb

        signal clicked

        color: ma.containsMouse ? root.accentColor : root.textColor
        font.family: root.mono
        font.pixelSize: 10

        MouseArea {
            id: ma

            anchors.fill: parent
            anchors.margins: -7
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: nb.clicked()
        }
    }

    component MediaBtn: Text {
        id: mb

        signal clicked

        color: ma.containsMouse ? root.accentColor : root.titleColor
        font.family: root.mono
        font.pixelSize: 12

        MouseArea {
            id: ma

            anchors.fill: parent
            anchors.margins: -7
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    component Gauge: Rectangle {
        id: g

        property real value: -1
        property string valueText: "N/A"
        property string label: ""

        width: 54
        height: 54
        radius: 8
        color: root.tint(root.accentColor, 0.14)
        border.width: 1
        border.color: root.tint(root.accentColor, 0.3 + 0.35 * root.pulse)

        Behavior on value { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        Canvas {
            id: gw

            anchors.fill: parent
            anchors.margins: 1
            visible: g.value > 0
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Cooperative

            Connections {
                target: root

                function onWavePhaseChanged() {
                    if (gw.visible)
                        gw.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                var W = width
                var H = height

                ctx.clearRect(0, 0, W, H)

                if (W <= 0 || g.value <= 0)
                    return

                ctx.save()
                ctx.beginPath()
                ctx.roundedRect(0, 0, W, H, 7, 7)
                ctx.clip()

                var lv = Math.min(1, g.value / 100)
                var mix = Qt.tint(root.accentColor, root.tint(root.toneB, 0.5))
                var layers = [
                    { freq: 1.3, spd: 0.8, off: 0.0, col: root.toneB, a: 0.45, ln: 0.5 },
                    { freq: 1.8, spd: -1.1, off: 2.1, col: mix, a: 0.4, ln: 0.8 }
                ]
                var n = 24

                for (var L = 0; L < layers.length; L++) {
                    var ly = layers[L]
                    var amp = 0.05 + 0.05 * lv

                    ctx.beginPath()

                    for (var k = 0; k <= n; k++) {
                        var u = k / n
                        var w = Math.sin(u * ly.freq * 6.2832 + root.wavePhase * ly.spd + ly.off)
                        var y = H - (lv * H * 0.9 + 0.04 * H) - w * amp * H

                        if (k === 0)
                            ctx.moveTo(0, y)
                        else
                            ctx.lineTo(u * W, y)
                    }

                    ctx.lineJoin = "round"
                    ctx.lineWidth = 1.2
                    ctx.strokeStyle = root.rgba(ly.col, ly.ln)
                    ctx.stroke()

                    ctx.lineTo(W, H)
                    ctx.lineTo(0, H)
                    ctx.closePath()

                    var gr = ctx.createLinearGradient(0, 0, 0, H)
                    gr.addColorStop(0, root.rgba(ly.col, ly.a))
                    gr.addColorStop(1, root.rgba(ly.col, ly.a * 0.15))
                    ctx.fillStyle = gr
                    ctx.fill()
                }

                ctx.restore()
            }

            Connections {
                target: g

                function onValueChanged() {
                    gw.requestPaint()
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.valueText
                color: root.titleColor
                font.family: root.mono
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.label
                color: root.toneB
                font.family: root.mono
                font.pixelSize: 8
            }
        }
    }

    component DiskRow: Item {
        id: dr

        property string label: ""
        property real value: 0

        width: parent ? parent.width : 220
        height: 18

        Text {
            text: dr.label
            width: 46
            color: root.textColor
            font.family: root.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            x: 46
            width: parent.width - 46 - 38
            height: 6
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.lineColor

            Rectangle {
                width: parent.width * Math.min(1, dr.value / 100)
                height: parent.height
                radius: 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.accentColor }
                    GradientStop { position: 1.0; color: root.toneB }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: root.accentColor
                    shadowBlur: 1.0
                    shadowOpacity: 0.3 + 0.6 * root.pulse
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: dr.value + "%"
            color: root.titleColor
            font.family: root.mono
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    HyprlandFocusGrab {
        windows: [win]
        active: true

        onCleared: {
            Quickshell.execDetached(["sh", "-c", "date +%s%N > \"${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$1\"", "doiz", "dashboard"])
            root.closePopup()
        }
    }

    PanelWindow {
        id: win

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        margins {
            top: 30
            left: root.popX(root.panelW + 12, (root.barScrW - root.panelW - 12) / 2)
        }

        implicitWidth: root.panelW + 12
        implicitHeight: root.panelH + 6 + 10

        WlrLayershell.namespace: "doiz-dashboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: card

            x: 6
            y: 0
            width: root.panelW
            height: root.panelH
            radius: 12
            color: root.panelColor
            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 13000
            }
            border.width: 1
            border.color: root.tint(root.accentColor, 0.45)
            focus: true
            opacity: 0

            Component.onCompleted: {
                opacity = 1
                y = 10
            }

            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Keys.onEscapePressed: root.closePopup()

            Item {
                id: avatar

                x: 28
                y: 22
                width: 88
                height: 88

                Repeater {
                    model: 2

                    delegate: Rectangle {
                        id: ring

                        required property int index

                        anchors.centerIn: parent
                        width: avatar.width
                        height: avatar.height
                        radius: width / 2
                        color: "transparent"
                        border.width: 1.5
                        border.color: index === 0 ? root.accentColor : root.toneB
                        opacity: 0
                        scale: 1

                        SequentialAnimation {
                            running: true
                            loops: Animation.Infinite

                            PauseAnimation { duration: ring.index * 1300 }

                            ParallelAnimation {
                                NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.3; duration: 2600; easing.type: Easing.OutCubic }
                                NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 2600 }
                            }
                        }
                    }
                }

                Image {
                    id: face

                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 208
                    sourceSize.height: 208
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: faceMask

                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: face.status === Image.Ready ? "transparent" : root.cardColor
                    border.width: 1.5
                    border.color: root.accentColor

                    GlowText {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        glowColor: root.accentColor
                        period: 2600
                        text: "\uDB80\uDC04"
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 34
                    }
                }
            }

            GlowText {
                x: avatar.x - 10
                y: 132
                width: avatar.width + 20
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                glowColor: root.accentColor
                period: 2400
                delay: 800
                text: root.userName
                color: root.titleColor
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Column {
                x: avatar.x - 10
                y: 162
                width: avatar.width + 20
                spacing: 9

                Repeater {
                    model: [
                        { k: "Uptime", v: root.sysUptime },
                        { k: "Kernel", v: root.sysKernel },
                        { k: "Session", v: root.sysDesk }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 40
                        radius: 8
                        color: root.tint(root.accentColor, 0.1)
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.28)

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            spacing: 3

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.k
                                color: root.mutedColor
                                font.family: root.mono
                                font.pixelSize: 8
                            }

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: modelData.v
                                color: root.titleColor
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }

            Row {
                id: clockRow

                x: 150
                y: 66 - height / 2
                spacing: 16

                Row {
                    id: clockDigits

                    anchors.verticalCenter: parent.verticalCenter

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: true
                        shadowEnabled: true
                        shadowColor: root.accentColor
                        shadowBlur: 1.0
                        shadowOpacity: 0.4 + 0.5 * root.pulse
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Text {
                        text: Qt.formatDateTime(clock.date, "HH")
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }

                    Text {
                        text: ":"
                        color: root.toneB
                        opacity: clock.date.getSeconds() % 2 === 0 ? 1 : 0.25
                        font.family: root.mono
                        font.pixelSize: 30
                        font.weight: Font.Bold

                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    Text {
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    GlowText {
                        glowColor: root.accentColor
                        period: 3200
                        delay: 400
                        text: Qt.formatDateTime(clock.date, "dddd")
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: Qt.formatDateTime(clock.date, "dd/MM/yyyy")
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            GlowText {
                x: 150
                y: 128
                glowColor: root.toneB
                period: 3600
                delay: 400
                text: "Calendar"
                color: root.toneB
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Item {
                x: 150
                y: 152
                width: 210
                height: 20

                NavBtn {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf053"
                    onClicked: root.shiftMonth(-1)
                }

                Text {
                    anchors.centerIn: parent
                    text: root.monthNames[root.viewMonth] + " " + root.viewYear
                    color: root.titleColor
                    font.family: root.mono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                NavBtn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf054"
                    onClicked: root.shiftMonth(1)
                }
            }

            Grid {
                x: 150
                y: 176
                columns: 7

                Repeater {
                    model: root.weekdayNames

                    Text {
                        required property string modelData

                        width: 30
                        height: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }

                Repeater {
                    model: root.cells

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool isToday: modelData.cur
                            && modelData.d === root.todayD
                            && root.viewMonth === root.todayM
                            && root.viewYear === root.todayY
                        readonly property bool weekend: index % 7 >= 5

                        width: 30
                        height: 24

                        Rectangle {
                            id: todayBox

                            property real pulse: 0.3

                            anchors.centerIn: parent
                            width: 24
                            height: 21
                            radius: 6
                            visible: cell.isToday

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.accentColor }
                                GradientStop { position: 1.0; color: root.toneB }
                            }

                            layer.enabled: cell.isToday
                            layer.effect: MultiEffect {
                                autoPaddingEnabled: true
                                shadowEnabled: true
                                shadowColor: root.toneB
                                shadowBlur: 1.0
                                shadowOpacity: todayBox.pulse
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }

                            SequentialAnimation on pulse {
                                running: cell.isToday
                                loops: Animation.Infinite

                                NumberAnimation { to: 1.0; duration: 1300; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.3; duration: 1300; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cell.modelData.cur
                            text: cell.modelData.d
                            color: cell.isToday ? root.inkColor : cell.weekend ? root.toneB : root.titleColor
                            font.family: root.mono
                            font.pixelSize: 10
                            font.weight: cell.isToday ? Font.Bold : Font.DemiBold
                        }
                    }
                }
            }

            Item {
                id: media

                x: 392
                y: 34
                width: 220
                height: 64

                Item {
                    id: spectrumBox

                    x: 70
                    y: 0
                    width: parent.width - 70
                    height: parent.height

                    Item {
                        id: backWave

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.round(parent.height * 0.5)
                        opacity: 0.85

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 16
                        }

                        Row {
                            id: backRow

                            width: backWave.width
                            height: backWave.height
                            anchors.bottom: parent.bottom
                            spacing: 0

                            Repeater {
                                model: root.barCount

                                delegate: Item {
                                    id: bcell

                                    required property int index
                                    readonly property real v: root.waveLevel(root.levels[bcell.index])

                                    width: backWave.width / root.barCount
                                    height: backRow.height

                                    Rectangle {
                                        width: parent.width + 2
                                        height: bcell.v > 0.02 ? Math.max(6, bcell.v * backRow.height) : 0
                                        anchors.bottom: parent.bottom

                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.0) }
                                            GradientStop { position: 1.0; color: root.accentColor }
                                        }

                                        Behavior on height { NumberAnimation { duration: 90 } }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: spectrum

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.round(parent.height * 0.4)

                        Row {
                            id: wave

                            width: spectrum.width
                            height: spectrum.height
                            anchors.bottom: parent.bottom
                            spacing: 0

                            Repeater {
                                model: root.barCount

                                delegate: Item {
                                    id: cell

                                    required property int index
                                    readonly property real v: root.waveLevel(root.levels[cell.index])
                                    readonly property real h: cell.v > 0.02 ? 3 + Math.round(cell.v * (wave.height - 10) / 3) * 3 : 0

                                    width: spectrum.width / root.barCount
                                    height: wave.height

                                    Rectangle {
                                        id: body

                                        width: parent.width + 1
                                        height: cell.h
                                        anchors.bottom: parent.bottom
                                        color: root.accentColor

                                        Behavior on height { NumberAnimation { duration: 60 } }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    x: 0
                    y: 2
                    width: 60
                    height: 60
                    radius: 4
                    color: root.tint(root.accentColor, 0.2)
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    GlowText {
                        anchors.centerIn: parent
                        text: "\uf001"
                        glowColor: root.accentColor
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 20
                        visible: !root.player || !root.player.trackArtUrl
                    }
                }

                Column {
                    x: 70
                    y: 2
                    width: parent.width - 70
                    spacing: 2

                    GlowText {
                        width: parent.width
                        elide: Text.ElideRight
                        period: 3000
                        glowColor: root.toneB
                        text: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing playing"
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player && root.player.trackArtist ? root.player.trackArtist : "-"
                        color: root.textColor
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                }

                Row {
                    x: 70 + (parent.width - 70 - width) / 2
                    y: 42
                    spacing: 28

                    MediaBtn { text: "\uf048"; onClicked: if (root.player) root.player.previous() }
                    MediaBtn {
                        text: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                    MediaBtn { text: "\uf051"; onClicked: if (root.player) root.player.next() }
                }
            }

            Item {
                id: mon

                x: 392
                y: 128
                width: 220
                height: 170

                GlowText {
                    text: "Monitor"
                    period: 3600
                    delay: 800
                    glowColor: root.toneB
                    color: root.toneB
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Rectangle {
                    anchors.right: parent.right
                    width: modeText.implicitWidth + 16
                    height: 16
                    radius: 3
                    color: root.tint(root.toneB, 0.18)
                    border.width: 1
                    border.color: root.tint(root.toneB, 0.5)

                    Text {
                        id: modeText

                        anchors.centerIn: parent
                        text: root.gpuMode ? "GPU" : "System"
                        color: root.toneB
                        font.family: root.mono
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.gpuMode = !root.gpuMode
                    }
                }

                NavBtn {
                    x: 25 - width / 2
                    y: 51 - height / 2
                    text: "\uf053"
                    onClicked: root.gpuMode = !root.gpuMode
                }

                Gauge {
                    x: 74 - width / 2
                    y: 24
                    value: root.gpuMode ? root.gpuP : root.cpuP
                    valueText: value < 0 ? "N/A" : Math.round(value) + "%"
                    label: root.gpuMode ? "GPU" : "CPU"
                }

                Gauge {
                    x: 146 - width / 2
                    y: 24
                    value: root.gpuMode ? root.vramP : root.memP
                    valueText: root.gpuMode
                        ? (root.vramP < 0 ? "N/A" : root.vramGb + " GB")
                        : root.memGb + " GB"
                    label: root.gpuMode ? "VRAM" : "RAM"
                }

                NavBtn {
                    x: 195 - width / 2
                    y: 51 - height / 2
                    text: "\uf054"
                    onClicked: root.gpuMode = !root.gpuMode
                }

                Column {
                    y: 98
                    width: parent.width
                    spacing: 10

                    DiskRow { label: "Root /"; value: root.rootP }
                    DiskRow { label: "/boot"; value: root.bootP; visible: root.bootP >= 0 }
                    DiskRow { label: "Home"; value: root.homeP }
                }
            }
        }
    }
}
