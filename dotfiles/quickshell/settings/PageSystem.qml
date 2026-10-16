import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property string os: "--"
    property string wm: "--"
    property string uptime: "--"
    property string cpuName: "--"
    property string kernel: "--"
    property real cpuUsage: 0
    property real temp: 0
    property real memTotal: 0
    property real memUsed: 0
    property real memAvail: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property string gpuName: "--"
    property real gpuUsage: -1
    property real gpuTemp: -1
    property real vramUsed: -1
    property real vramTotal: -1
    property real gpuFreq: -1
    property var history: []
    property var lastStat: null

    function parse(text) {
        var lines = text.split("\n")
        var v = {}

        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].indexOf("=")

            if (s > 0)
                v[lines[i].substring(0, s)] = lines[i].substring(s + 1)
        }

        page.os = v["OS"] || "--"
        page.wm = v["WM"] || "--"
        page.uptime = v["UPTIME"] || "--"
        page.cpuName = (v["CPU"] || "--").trim()
        page.kernel = v["KERNEL"] || "--"

        if (v["STAT"]) {
            var f = v["STAT"].trim().split(/\s+/).slice(1, 9).map(Number)
            var total = 0

            for (var k = 0; k < f.length; k++)
                total += f[k]

            var idle = f[3] + (f[4] || 0)

            if (page.lastStat) {
                var dt = total - page.lastStat.total
                var di = idle - page.lastStat.idle

                if (dt > 0)
                    page.cpuUsage = Math.max(0, Math.min(100, 100 * (1 - di / dt)))
            }

            page.lastStat = { total: total, idle: idle }

            var h = page.history.slice()
            h.push(page.cpuUsage)

            if (h.length > 60)
                h.shift()

            page.history = h
        }

        var t = Number(v["TEMP"])

        if (!isNaN(t) && t > 0)
            page.temp = t > 1000 ? t / 1000 : t

        var x = (v["MEMX"] || "").split(" ")

        if (x.length >= 4) {
            page.memAvail = Number(x[0])
            page.memCached = Number(x[1])
            page.swapTotal = Number(x[2])
            page.swapUsed = Number(x[3])
        }

        var m = (v["MEM"] || "").split(" ")

        if (m.length >= 2) {
            page.memTotal = Number(m[0])
            page.memUsed = Number(m[1])
        }
    }

    function parseGpu(text) {
        var lines = text.split("\n")
        var v = {}

        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].indexOf("=")

            if (s > 0)
                v[lines[i].substring(0, s)] = lines[i].substring(s + 1).trim()
        }

        function num(key) {
            var n = parseFloat(v[key])
            return isNaN(n) ? -1 : n
        }

        page.gpuUsage = num("USAGE")
        page.gpuTemp = num("TEMP")
        page.vramUsed = num("VRAM_USED")
        page.vramTotal = num("VRAM_TOTAL")
        page.gpuFreq = num("FREQ")
    }

    function mib(v) {
        return v < 0 ? "--" : (v / 1024).toFixed(1) + " GiB"
    }

    function gib(kb) {
        return (kb / 1048576).toFixed(1) + " GiB"
    }

    readonly property real memPercent: page.memTotal > 0 ? page.memUsed / page.memTotal * 100 : 0

    readonly property bool hasHero: true

    property int faceRev: 0

    readonly property string pickScript: [
        "d=\"$HOME/Pictures/\"; [ -d \"$d\" ] || d=\"$HOME/\"",
        "if command -v zenity >/dev/null 2>&1; then",
        "  f=$(zenity --file-selection --title='Choose avatar' --filename=\"$d\" --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.PNG *.JPG *.JPEG *.WEBP *.GIF' 2>/dev/null)",
        "elif command -v kdialog >/dev/null 2>&1; then",
        "  f=$(kdialog --title 'Choose avatar' --getopenfilename \"$d\" 'image/*' 2>/dev/null)",
        "else",
        "  notify-send 'Settings' 'Install zenity or kdialog to choose an avatar' 2>/dev/null",
        "  exit 1",
        "fi",
        "[ -f \"$f\" ] && cp -f -- \"$f\" \"$HOME/.face.new\" && mv -f \"$HOME/.face.new\" \"$HOME/.face\"",
        "command -v setfacl >/dev/null 2>&1 && { setfacl -m u:sddm:x \"$HOME\"; setfacl -m u:sddm:r \"$HOME/.face\"; } 2>/dev/null; exit 0"
    ].join("\n")

    Component.onDestruction: Theme.picking = false

    readonly property color cpuTone: page.cpuUsage >= 85 ? Theme.badColor : page.cpuUsage >= 60 ? Theme.warnColor : Theme.goodColor
    readonly property color memTone: page.memPercent >= 85 ? Theme.badColor : page.memPercent >= 65 ? Theme.warnColor : Theme.infoColor

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Item {
            width: parent.width
            height: 84

            Process {
                id: picker

                command: ["sh", "-c", page.pickScript]

                onRunningChanged: Theme.picking = picker.running
                onExited: page.faceRev++
            }

            Rectangle {
                id: avatar

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 84
                height: 84
                radius: 8
                clip: true
                color: Theme.tint(Theme.accentColor, 0.16)
                border.width: avatarMouse.containsMouse ? 1 : 0
                border.color: Theme.accentColor

                Image {
                    id: face

                    anchors.fill: parent
                    source: "file://" + Theme.home + "/.face?r=" + page.faceRev
                    sourceSize.width: 256
                    sourceSize.height: 256
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: face.status === Image.Ready
                }

                TextMetrics {
                    id: logoMetrics

                    font.family: Theme.fontName
                    font.pixelSize: 40
                    text: "\uDB82\uDCC7"
                }

                Lbl {
                    id: logo

                    readonly property rect box: logoMetrics.tightBoundingRect

                    x: Math.round((avatar.width - box.width) / 2 - box.x)
                    y: Math.round((avatar.height - box.height) / 2 - (logo.baselineOffset + box.y))
                    visible: face.status !== Image.Ready
                    text: "\uDB82\uDCC7"
                    color: Theme.accentColor
                    font.pixelSize: 40
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 18
                    color: "#99000000"
                    opacity: avatarMouse.containsMouse ? 1 : 0

                    Lbl {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "CHANGE"
                        color: "#ffffff"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                    }
                }

                MouseArea {
                    id: avatarMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (!picker.running)
                            picker.running = true
                    }
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 10
                anchors.right: upBox.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Lbl {
                    width: parent.width
                    text: "SYSTEM"
                    color: Theme.titleColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }

                Lbl {
                    width: parent.width
                    text: page.os
                    color: Theme.accentColor
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: upBox

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 110
                height: 40
                radius: 8
                color: Theme.cardColor

                Lbl {
                    anchors.fill: parent
                    anchors.margins: 4
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: page.uptime
                    color: Theme.accentColor
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Stat {
                width: (parent.width - 12) / 3
                label: "KERNEL"
                value: page.kernel
                tone: Theme.accentColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "WM"
                value: page.wm
                tone: Theme.accentColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "TEMP"
                value: page.temp > 0 ? Math.round(page.temp) + "°C" : "--"
                tone: page.temp >= 80 ? Theme.badColor : page.temp >= 65 ? Theme.warnColor : Theme.goodColor
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineColor
        }

        Head {
            width: parent.width
            title: "CPU"
            info: Math.round(page.cpuUsage) + "%"
        }

        Card {
            width: parent.width
            height: 104

            Lbl {
                id: cpuLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                horizontalAlignment: Text.AlignHCenter
                text: page.cpuName
                color: Theme.titleColor
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: graphBox

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: cpuLabel.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 12
                anchors.topMargin: 8
                radius: 4
                color: Theme.trackColor

                Canvas {
                    id: graph

                    anchors.fill: parent

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()

                        var w = width
                        var h = height

                        ctx.strokeStyle = Theme.tint(Theme.mutedColor, 0.2)
                        ctx.lineWidth = 1

                        for (var g = 1; g < 4; g++) {
                            var gy = Math.round(h * g / 4) + 0.5
                            ctx.beginPath()
                            ctx.moveTo(0, gy)
                            ctx.lineTo(w, gy)
                            ctx.stroke()
                        }

                        var data = page.history
                        var n = data.length

                        if (n < 2)
                            return

                        var step = w / 59
                        var x0 = w - (n - 1) * step

                        function py(v) {
                            return h - 4 - (v / 100) * (h - 8)
                        }

                        ctx.beginPath()
                        ctx.moveTo(x0, py(data[0]))

                        for (var i = 1; i < n; i++)
                            ctx.lineTo(x0 + i * step, py(data[i]))

                        ctx.strokeStyle = page.cpuTone
                        ctx.lineWidth = 1.5
                        ctx.stroke()

                        ctx.lineTo(x0 + (n - 1) * step, h)
                        ctx.lineTo(x0, h)
                        ctx.closePath()
                        ctx.fillStyle = Theme.tint(page.cpuTone, 0.18)
                        ctx.fill()
                    }

                    Connections {
                        target: page

                        function onHistoryChanged() {
                            graph.requestPaint()
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Head {
                width: (parent.width - 8) / 2
                title: "MEMORY"
                info: Math.round(page.memPercent) + "%"
            }

            Head {
                width: (parent.width - 8) / 2
                title: "GPU"
                info: page.gpuUsage >= 0 ? Math.round(page.gpuUsage) + "%" : "--"
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Card {
                width: (parent.width - 8) / 2
                height: 138

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Lbl {
                        width: parent.width
                        height: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: page.gib(page.memUsed) + " / " + page.gib(page.memTotal)
                        color: Theme.titleColor
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    Track {
                        width: parent.width
                        value: page.memPercent
                        interactive: false
                        tone: page.memTone
                    }

                    KV {
                        width: parent.width
                        label: "AVAILABLE"
                        value: page.gib(page.memAvail)
                        tone: Theme.goodColor
                    }

                    KV {
                        width: parent.width
                        label: "CACHED"
                        value: page.gib(page.memCached)
                        tone: Theme.infoColor
                    }

                    KV {
                        width: parent.width
                        label: "SWAP"
                        value: page.swapTotal > 0 ? page.gib(page.swapUsed) + " / " + page.gib(page.swapTotal) : "off"
                        tone: page.swapTotal > 0 && page.swapUsed / page.swapTotal > 0.5 ? Theme.warnColor : Theme.accentColor
                    }
                }
            }

            Card {
                width: (parent.width - 8) / 2
                height: 138

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Lbl {
                        width: parent.width
                        height: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: page.gpuName.replace(/ Corporation/, "").replace(/\s*\(rev [0-9a-f]+\)/i, "")
                        color: Theme.titleColor
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Track {
                        width: parent.width
                        value: Math.max(0, page.gpuUsage)
                        interactive: false
                        tone: page.gpuUsage >= 85 ? Theme.badColor : page.gpuUsage >= 60 ? Theme.warnColor : Theme.accentColor
                    }

                    KV {
                        width: parent.width
                        label: "VRAM"
                        value: page.vramTotal > 0 ? page.mib(page.vramUsed) + " / " + page.mib(page.vramTotal) : "--"
                        tone: Theme.infoColor
                    }

                    KV {
                        width: parent.width
                        label: "TEMP"
                        value: page.gpuTemp >= 0 ? Math.round(page.gpuTemp) + "°C" : "--"
                        tone: page.gpuTemp >= 85 ? Theme.badColor : page.gpuTemp >= 70 ? Theme.warnColor : Theme.goodColor
                    }

                    KV {
                        width: parent.width
                        label: "CLOCK"
                        value: page.gpuFreq >= 0 ? Math.round(page.gpuFreq) + " MHz" : "--"
                        tone: Theme.accentColor
                    }
                }
            }
        }
    }

    Process {
        id: sysProc

        command: ["sh", Theme.dir + "/sysinfo.sh"]

        stdout: StdioCollector {
            onStreamFinished: page.parse(this.text)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!sysProc.running)
                sysProc.running = true
        }
    }

    Process {
        id: gpuNameProc

        command: ["sh", Theme.dir + "/gpu.sh", "name"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: page.gpuName = this.text.trim() || "No GPU found"
        }
    }

    Process {
        id: gpuProc

        command: ["nice", "-n", "19", "sh", Theme.dir + "/gpu.sh", "stat"]

        stdout: StdioCollector {
            onStreamFinished: page.parseGpu(this.text)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!gpuProc.running)
                gpuProc.running = true
        }
    }
}
