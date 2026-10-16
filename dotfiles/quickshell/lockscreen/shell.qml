import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pam

ShellRoot {
    id: root

    property real glassA: 1.0
    property color panelColor: Qt.rgba(basePanelColor.r, basePanelColor.g, basePanelColor.b, Math.min(basePanelColor.a, root.glassA))
    property color cardColor: Qt.rgba(baseCardColor.r, baseCardColor.g, baseCardColor.b, Math.min(baseCardColor.a, root.glassA))

    property real lockBlur: 100

    FileView {
        path: root.cfgHome + "/mycfg/lock-blur"
        onLoaded: {
            var b = parseFloat(text())
            root.lockBlur = isNaN(b) ? 100 : Math.max(0, Math.min(100, b))
        }
        onLoadFailed: root.lockBlur = 100
    }

    FileView {
        path: root.cfgHome + "/mycfg/bar-glass"
        onLoaded: {
            var l = text().split("\n")
            var p = parseFloat(l[1])
            if (isNaN(p)) p = 50
            root.glassA = l[0].trim() === "on" ? Math.max(0.2, Math.min(1, p / 100)) : 1.0
        }
        onLoadFailed: root.glassA = 1.0
    }

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string font: "JetBrainsMono Nerd Font"

    property color basePanelColor: "#f51b1b1b"
    property color baseCardColor: "#942a2a2a"
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#9a9a9a"
    property color inkColor: "#1b1b1b"
    property color okColor: "#81aa99"
    property color failColor: "#b2729e"
    property color cyanColor: "#8f8f8f"
    property color blueColor: "#9a9a9a"
    property color yellowColor: "#aa978b"
    property color backdropColor: "#101010"
    property bool themeReady: false

    Behavior on basePanelColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on baseCardColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on lineColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on titleColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on textColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on mutedColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on accentColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on inkColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on okColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on failColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on cyanColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on blueColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on yellowColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }
    Behavior on backdropColor { enabled: root.themeReady; ColorAnimation { duration: 600 } }

    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    readonly property color toneC: Qt.lighter(accentColor, 1.7)

    function shiftHue(c, d) {
        var h = ((c.hslHue + d) % 1 + 1) % 1
        return Qt.hsla(h, c.hslSaturation, c.hslLightness, 1)
    }
    readonly property color hueA: shiftHue(accentColor, 0.07)
    readonly property color hueB: shiftHue(accentColor, -0.07)
    readonly property color hueC: shiftHue(accentColor, 0.14)
    readonly property color hueD: shiftHue(accentColor, -0.14)
    readonly property var tonePalette: [accentColor, toneB, toneC, toneB, accentColor]
    readonly property var dotPalette: [accentColor, hueA, hueB, hueC, hueD]

    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real bat: -1
    property string batState: ""
    property string wifi: ""
    property int vol: -1
    property int uptimeSec: 0
    property string kbLayout: ""
    property var notifs: []
    readonly property var quotes: [
        "Small steps still move you forward.",
        "Make it work, then make it beautiful.",
        "Done is better than perfect.",
        "Stay curious, ship often.",
        "Every expert was once a beginner.",
        "Simplicity is the ultimate sophistication.",
        "Great things take time. Keep going.",
        "Focus on the signal, not the noise."
    ]
    property int quoteIdx: Math.floor(Math.random() * quotes.length)

    function greeting(d) {
        var h = d.getHours()
        var t = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return t + ", " + userName
    }

    function layoutCode(name) {
        var w = (name || "").split(/[ (]/)[0]
        return w.slice(0, 2).toUpperCase()
    }
    property color clockGlow: accentColor
    property var wx: null
    readonly property bool wxReady: wx !== null && wx.ok === true

    function sysRows() {
        var r = [
            { icon: "", name: "cpu", v: cpu, a: accentColor, b: toneB },
            { icon: "󰍛", name: "ram", v: mem, a: accentColor, b: toneB },
            { icon: "󰋊", name: "disk", v: disk, a: accentColor, b: toneB }
        ]
        if (bat >= 0)
            r.push({ icon: batState === "Charging" ? "󰂄" : "󰁹", name: "battery", v: bat, a: accentColor, b: toneB })
        return r
    }

    function weekDays(d) {
        var x = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        x.setDate(x.getDate() - ((x.getDay() + 6) % 7))
        var out = []
        for (var i = 0; i < 7; i++) {
            out.push({ d: new Date(x.getFullYear(), x.getMonth(), x.getDate() + i), idx: i })
        }
        return out
    }

    function monthCells(d) {
        var first = new Date(d.getFullYear(), d.getMonth(), 1)
        var off = (first.getDay() + 6) % 7
        var total = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        var rows = Math.ceil((off + total) / 7)
        var out = []
        for (var i = 0; i < rows * 7; i++) {
            var n = i - off + 1
            out.push({ n: n, on: n >= 1 && n <= total, we: i % 7 >= 5 })
        }
        return out
    }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var n = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - n)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    function fmtUp(sec) {
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    Process {
        id: statsProc
        command: ["bash", Quickshell.shellDir + "/stats.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var l = this.text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var k = l[i].indexOf("=")
                    if (k < 0) continue
                    var key = l[i].substring(0, k)
                    var v = l[i].substring(k + 1).trim()
                    if (key === "cpu") root.cpu = parseFloat(v) || 0
                    else if (key === "mem") root.mem = parseFloat(v) || 0
                    else if (key === "disk") root.disk = parseFloat(v) || 0
                    else if (key === "bat") root.bat = v === "" ? -1 : (parseFloat(v) || 0)
                    else if (key === "batstate") root.batState = v
                    else if (key === "wifi") root.wifi = v
                    else if (key === "vol") root.vol = v === "" ? -1 : (parseInt(v) || 0)
                    else if (key === "up") root.uptimeSec = parseInt(v) || 0
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!statsProc.running)
                statsProc.running = true
        }
    }

    Process {
        id: wxProc
        command: ["python3", root.cfgHome + "/quickshell/weatherpopup/weather.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.wx = JSON.parse(this.text)
                } catch (e) {
                    root.wx = { ok: false }
                }
            }
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!wxProc.running)
                wxProc.running = true
        }
    }

    Process {
        id: kbProc
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var kb = JSON.parse(this.text).keyboards || []
                    var pick = null
                    for (var i = 0; i < kb.length; i++) {
                        if (kb[i].main) { pick = kb[i]; break }
                        if (pick === null) pick = kb[i]
                    }
                    root.kbLayout = pick ? root.layoutCode(pick.active_keymap) : ""
                } catch (e) {
                    root.kbLayout = ""
                }
            }
        }
    }

    Process {
        id: notifProc
        command: ["qs", "-c", "notifd", "ipc", "call", "notifd", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var a = JSON.parse(this.text.trim())
                    root.notifs = Array.isArray(a) ? a : []
                } catch (e) {
                    root.notifs = []
                }
            }
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!kbProc.running)
                kbProc.running = true
            if (!notifProc.running)
                notifProc.running = true
        }
    }

    property real lastData: 0
    property real lastSound: 0

    Process {
        id: cavaProc
        running: true
        command: ["cava", "-p", Quickshell.shellDir + "/cava/config"]

        stdout: SplitParser {
            onRead: data => {
                var p = data.split(";")
                var a = []
                var peak = 0
                for (var i = 0; i < p.length; i++) {
                    if (p[i] === "") continue
                    var n = parseInt(p[i]) || 0
                    if (n > peak) peak = n
                    a.push(n)
                }
                var now = Date.now()
                root.lastData = now
                if (peak > 2) root.lastSound = now
                root.bars = a
            }
        }

        onRunningChanged: {
            if (!running) {
                root.bars = []
                cavaRestart.restart()
            }
        }
    }

    Timer {
        id: cavaRestart
        interval: 400
        onTriggered: {
            root.lastData = Date.now()
            root.lastSound = Date.now()
            cavaProc.running = true
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!cavaProc.running) return
            var now = Date.now()
            var stalled = now - root.lastData > 4000
            var deaf = root.player !== null && root.player.isPlaying && now - root.lastSound > 4000
            if (stalled || deaf) cavaProc.running = false
        }
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

        root.basePanelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.90)
        root.baseCardColor = Qt.rgba(sf.r, sf.g, sf.b, 0.92)
        root.lineColor = Qt.rgba(mu.r, mu.g, mu.b, 0.3)
        root.inkColor = bg
        root.titleColor = pick("foreground", "#e0e0e0")
        root.textColor = pick("subtext", "#a8a8a8")
        root.mutedColor = pick("muted", "#777777")
        root.accentColor = pick("accent_alt", pick("accent", "#8a8a8a"))
        root.okColor = pick("green", "#81AA99")
        root.failColor = pick("red", "#B2729E")
        root.cyanColor = pick("cyan", "#8f8f8f")
        root.blueColor = pick("blue", "#9a9a9a")
        root.yellowColor = pick("yellow", "#AA978B")
        root.backdropColor = Qt.darker(bg, 1.6)
        root.themeReady = true
    }

    FileView {
        id: themeFile
        path: root.cfgHome + "/theme/theme.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseTheme(text())
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: { themeFile.reload(); wpFile.reload() }
    }

    property int bgRev: 0
    property string wpPath: ""

    FileView {
        id: wpFile
        path: root.stateHome + "/doiz/current-wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var cur = text().split("\n")[0].trim()
            if (root.wpPath !== "" && cur !== root.wpPath)
                bgDebounce.restart()
            root.wpPath = cur
        }
    }

    Timer {
        id: bgDebounce
        interval: 400
        onTriggered: bgProc.running = true
    }

    Process {
        id: bgProc
        command: ["bash", root.cfgHome + "/hypr/scripts/lock.sh", "--bg"]
        onExited: root.bgRev++
    }

    component Glow: Canvas {
        id: glow
        property color tint: "white"
        property real strength: 0.5

        onTintChanged: requestPaint()
        onStrengthChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = width / 2
            var g = ctx.createRadialGradient(r, r, 0, r, r, r)
            g.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, strength))
            g.addColorStop(0.5, Qt.rgba(tint.r, tint.g, tint.b, strength * 0.35))
            g.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
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

    component GradBorder: Item {
        id: gb

        property real rr: 12
        property color c1: "white"
        property color c2: "white"
        property color c3: "white"
        property color c4: "white"
        property int cycle: 9000

        anchors.fill: parent

        Item {
            x: gb.rr
            y: 0
            width: parent.width - gb.rr * 2
            height: 1.5
            clip: true

            Rectangle {
                id: topBand
                height: parent.height
                width: parent.width * 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: gb.c1 }
                    GradientStop { position: 0.125; color: gb.c2 }
                    GradientStop { position: 0.25; color: gb.c3 }
                    GradientStop { position: 0.375; color: gb.c4 }
                    GradientStop { position: 0.5; color: gb.c1 }
                    GradientStop { position: 0.625; color: gb.c2 }
                    GradientStop { position: 0.75; color: gb.c3 }
                    GradientStop { position: 0.875; color: gb.c4 }
                    GradientStop { position: 1.0; color: gb.c1 }
                }

                NumberAnimation on x { from: 0; to: -topBand.width / 2; duration: gb.cycle; loops: Animation.Infinite }
            }
        }

        Item {
            x: gb.rr
            y: parent.height - 1.5
            width: parent.width - gb.rr * 2
            height: 1.5
            clip: true

            Rectangle {
                id: botBand
                height: parent.height
                width: parent.width * 2

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: gb.c3 }
                    GradientStop { position: 0.125; color: gb.c4 }
                    GradientStop { position: 0.25; color: gb.c1 }
                    GradientStop { position: 0.375; color: gb.c2 }
                    GradientStop { position: 0.5; color: gb.c3 }
                    GradientStop { position: 0.625; color: gb.c4 }
                    GradientStop { position: 0.75; color: gb.c1 }
                    GradientStop { position: 0.875; color: gb.c2 }
                    GradientStop { position: 1.0; color: gb.c3 }
                }

                NumberAnimation on x { from: -botBand.width / 2; to: 0; duration: gb.cycle; loops: Animation.Infinite }
            }
        }

        Rectangle {
            x: 0
            y: gb.rr
            width: 1.5
            height: parent.height - gb.rr * 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: gb.c1 }
                GradientStop { position: 1.0; color: gb.c4 }
            }
        }

        Rectangle {
            x: parent.width - 1.5
            y: gb.rr
            width: 1.5
            height: parent.height - gb.rr * 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: gb.c2 }
                GradientStop { position: 1.0; color: gb.c3 }
            }
        }
    }

    component DotRing: Canvas {
        id: dr

        property var palette: []
        property int count: 60
        property real ringRadius: 220
        property real dotSize: 2.2
        property int spin: 120000

        width: ringRadius * 2 + 16
        height: width

        onPaletteChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!palette || palette.length === 0) return
            var c = width / 2
            for (var i = 0; i < count; i++) {
                var a = i / count * Math.PI * 2
                var col = palette[i % palette.length]
                var big = i % 5 === 0
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, big ? 1.0 : 0.55)
                ctx.beginPath()
                ctx.arc(c + Math.cos(a) * ringRadius, c + Math.sin(a) * ringRadius, big ? dotSize * 1.8 : dotSize, 0, Math.PI * 2)
                ctx.fill()
            }
        }

        RotationAnimation on rotation { from: 0; to: 360; duration: dr.spin; loops: Animation.Infinite }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property var player: pickPlayer(Mpris.players.values)

    function pickPlayer(list) {
        var first = null
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
            if (first === null)
                first = list[i]
        }
        return first
    }

    property real pcPos: 0
    property real pcLen: 0
    property bool pcOk: false
    property bool seekBusy: false

    function playerArgs() {
        var n = root.player && root.player.dbusName ? String(root.player.dbusName).replace("org.mpris.MprisPlayer2.", "") : ""
        return n !== "" ? ["-p", n] : []
    }

    Process {
        id: pcProc
        command: ["playerctl"].concat(root.playerArgs(), ["metadata", "--format", "{{position}}|{{mpris:length}}"])

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length >= 2) {
                    var pos = (Number(parts[0]) || 0) / 1000000
                    var len = (Number(parts[1]) || 0) / 1000000
                    root.pcOk = len > 0
                    root.pcLen = len
                    root.pcPos = Math.min(pos, len > 0 ? len : pos)
                } else {
                    root.pcOk = false
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.player !== null
        triggeredOnStart: true
        onTriggered: {
            if (!pcProc.running && !root.seekBusy)
                pcProc.running = true
        }
    }

    function fmt(sec) {
        var t = Math.max(0, Math.floor(sec || 0))
        var m = Math.floor(t / 60)
        var s = t % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.player !== null && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    property string pw: ""
    property bool failed: false
    property bool busy: false
    property bool unlocking: false
    property int shakeTick: 0
    property int attempts: 0
    property var bars: []

    function waveLevel(n) {
        var x = Math.max(0, Math.min(1, (n || 0) / 100))
        return 1 - Math.pow(1 - x, 2.0)
    }
    readonly property int barCount: 192

    PamContext {
        id: pam
        configDirectory: Qt.resolvedUrl("pam").toString().replace("file://", "")
        config: "doiz-lock"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.pw)
        }

        onCompleted: result => {
            if (result !== PamResult.Success)
                root.busy = false

            if (result === PamResult.Success) {
                root.busy = true
                root.unlocking = true
                unlockTimer.start()
            } else {
                root.failed = true
                root.pw = ""
                root.shakeTick++
                root.attempts++
                failTimer.restart()
            }
        }
    }

    Timer {
        id: unlockTimer
        interval: 560
        onTriggered: {
            lock.locked = false
            Qt.quit()
        }
    }

    Timer {
        id: failTimer
        interval: 1800
        onTriggered: root.failed = false
    }

    function submit() {
        if (root.busy || pam.active || root.pw.length === 0)
            return
        root.failed = false
        root.busy = true
        pam.start()
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surf

            color: root.backdropColor

            property real intro: 0
            property real outro: 0
            property real popP: 0
            property real spread: 0
            property bool go: false

            Timer {
                interval: 450
                running: wall.status !== Image.Loading
                onTriggered: surf.go = true
            }
            readonly property real open: root.unlocking ? 1 - surf.outro : surf.intro

            function waveReveal(it, soft) {
                return Math.min(1, surf.open * 2.2)
            }

            NumberAnimation {
                target: surf
                property: "outro"
                from: 0
                to: 1
                duration: 420
                easing.type: Easing.InCubic
                running: root.unlocking
            }

            NumberAnimation {
                target: surf
                property: "spread"
                to: 0
                duration: 520
                easing.type: Easing.InBack
                easing.overshoot: 1.15
                running: root.unlocking
            }

            NumberAnimation {
                target: surf
                property: "intro"
                from: 0
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
                running: surf.go
            }

            NumberAnimation {
                target: surf
                property: "spread"
                from: 0
                to: 1
                duration: 720
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
                running: surf.go
            }

            NumberAnimation {
                target: surf
                property: "popP"
                from: 0
                to: 1
                duration: 550
                easing.type: Easing.OutBack
                easing.overshoot: 2.0
                running: surf.go
            }

            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.cacheHome + "/doiz/lock-bg.jpg?r=" + root.bgRev
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: false
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true
                blurMax: 64
                blur: Math.min(1, root.lockBlur / 100 + (1 - surf.open) * 0.9)
                scale: 1 + 0.12 * (1 - surf.open)
                brightness: -0.04
                saturation: 0.45
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(root.backdropColor.r, root.backdropColor.g, root.backdropColor.b, 0.2)
            }

            Glow {
                width: 1000; height: 1000
                tint: root.accentColor; strength: 0.55
                x: -200; y: -250
                SequentialAnimation on x { loops: Animation.Infinite
                    NumberAnimation { to: 40; duration: 16000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -200; duration: 16000; easing.type: Easing.InOutSine } }
                SequentialAnimation on y { loops: Animation.Infinite
                    NumberAnimation { to: -120; duration: 21000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -250; duration: 21000; easing.type: Easing.InOutSine } }
            }

            Glow {
                width: 900; height: 900
                tint: root.hueB; strength: 0.5
                x: surf.width - 650; y: surf.height - 650
                SequentialAnimation on x { loops: Animation.Infinite
                    NumberAnimation { to: surf.width - 760; duration: 19000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: surf.width - 650; duration: 19000; easing.type: Easing.InOutSine } }
            }

            Glow {
                width: 700; height: 700
                tint: root.hueC; strength: 0.4
                x: surf.width - 520; y: -220
                SequentialAnimation on y { loops: Animation.Infinite
                    NumberAnimation { to: -60; duration: 23000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -220; duration: 23000; easing.type: Easing.InOutSine } }
            }

            Glow {
                width: 700; height: 700
                tint: root.hueD; strength: 0.4
                x: -160; y: surf.height - 480
                SequentialAnimation on x { loops: Animation.Infinite
                    NumberAnimation { to: 20; duration: 25000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -160; duration: 25000; easing.type: Easing.InOutSine } }
            }

            Glow {
                width: 650; height: 650
                tint: root.hueA; strength: 0.28
                x: surf.width * 0.5 - 325; y: -330
                SequentialAnimation on y { loops: Animation.Infinite
                    NumberAnimation { to: -200; duration: 26000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -330; duration: 26000; easing.type: Easing.InOutSine } }
            }

            Repeater {
                model: 18

                delegate: Rectangle {
                    id: pt

                    required property int index

                    readonly property real size: 2 + (index * 7) % 5
                    readonly property int dur: 16000 + (index * 1900) % 14000
                    readonly property real y0: ((index * 53) % 100) / 100 * surf.height

                    width: size
                    height: size
                    radius: size / 2
                    x: ((index * 197) % 101) / 101 * surf.width
                    y: y0
                    color: root.dotPalette[index % root.dotPalette.length]
                    opacity: 0.3 + (index % 4) * 0.12

                    SequentialAnimation {
                        running: true

                        NumberAnimation { target: pt; property: "y"; to: -10; duration: Math.max(1, Math.round(pt.dur * (pt.y0 + 10) / (surf.height + 20))) }

                        SequentialAnimation {
                            loops: Animation.Infinite
                            PropertyAction { target: pt; property: "y"; value: surf.height + 10 }
                            NumberAnimation { target: pt; property: "y"; to: -10; duration: pt.dur }
                        }
                    }
                }
            }

            Canvas {
                id: dotGrid
                anchors.fill: parent
                opacity: 0.9
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var base = Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.10)
                    var pal = root.dotPalette
                    var r = 0
                    for (var y = 16; y < height; y += 28) {
                        var c = 0
                        for (var x = 16; x < width; x += 28) {
                            var hot = (r * 5 + c * 3) % 11 === 0
                            var col = pal[(r + c) % pal.length]
                            ctx.fillStyle = hot ? Qt.rgba(col.r, col.g, col.b, 0.55) : base
                            ctx.beginPath()
                            ctx.arc(x, y, hot ? 2.1 : 1.3, 0, Math.PI * 2)
                            ctx.fill()
                            c++
                        }
                        r++
                    }
                }

                Connections {
                    target: root
                    function onDotPaletteChanged() { dotGrid.requestPaint() }
                    function onTitleColorChanged() { dotGrid.requestPaint() }
                }
            }

            Item {
                id: backWave

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(surf.height * 0.85)
                opacity: 0.85

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 36
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

                            readonly property real v: root.waveLevel(root.bars[bcell.index])

                            width: backWave.width / root.barCount
                            height: backRow.height

                            Rectangle {
                                width: parent.width + 2
                                height: Math.max(10, bcell.v * backRow.height)
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
                height: Math.round(surf.height * 0.6)

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

                            readonly property real v: root.waveLevel(root.bars[cell.index])
                            readonly property real h: 3 + Math.round(cell.v * (wave.height - 10) / 3) * 3

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

                            Rectangle {
                                width: parent.width + 1
                                height: 3
                                anchors.bottom: body.top
                                visible: cell.v > 0.04
                                color: root.toneC
                            }
                        }
                    }
                }
            }

            FocusScope {
                id: keys
                anchors.fill: parent
                focus: true

                Component.onCompleted: forceActiveFocus()

                Keys.onPressed: event => {
                    if (root.busy) { event.accepted = true; return }

                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submit()
                    } else if (event.key === Qt.Key_Escape) {
                        root.pw = ""
                    } else if (event.key === Qt.Key_Backspace) {
                        if (event.modifiers & Qt.ControlModifier)
                            root.pw = ""
                        else
                            root.pw = root.pw.slice(0, -1)
                    } else if (event.text.length > 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                        if (event.text.charCodeAt(0) >= 32) {
                            root.failed = false
                            root.pw += event.text
                        }
                    }
                    event.accepted = true
                }

                Glow {
                    width: 620; height: 620
                    anchors.centerIn: panel
                    tint: root.accentColor
                    strength: 0.5
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        NumberAnimation { from: 0.45; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.45; duration: 2600; easing.type: Easing.InOutSine } }
                }

                DotRing {
                    anchors.centerIn: panel
                    ringRadius: 250
                    count: 64
                    spin: 140000
                    palette: root.dotPalette
                    opacity: 0.75 * surf.waveReveal(panel, 900)
                }

                DotRing {
                    anchors.centerIn: panel
                    ringRadius: 330
                    count: 84
                    dotSize: 1.8
                    spin: 200000
                    rotation: 30
                    palette: root.dotPalette
                    opacity: 0.4 * surf.waveReveal(panel, 900)
                }

                Rectangle {
                    id: panel

                    width: 340
                    height: col.implicitHeight + 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -60
                    radius: 12
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))

                    opacity: surf.waveReveal(panel, 900)
                    scale: 0.90 + 0.10 * surf.open
                    transform: Translate { y: 26 * (1 - surf.open) }

                    GradBorder {
                        rr: 12
                        c1: root.accentColor
                        c2: root.toneB
                        c3: root.accentColor
                        c4: root.toneB
                        cycle: 9000
                    }

                    Column {
                        id: col
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 14

                        Column {
                            id: lk1
                            opacity: surf.waveReveal(lk1, 700)
                            width: parent.width
                            spacing: 0

                            Item {
                                width: parent.width
                                height: clockRow.implicitHeight

                                Row {
                                    id: clockRow
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    property real pulse: 0

                                    SequentialAnimation on pulse {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 1; duration: 2400; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 0; duration: 2400; easing.type: Easing.InOutSine }
                                    }

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: root.clockGlow
                                        shadowBlur: 1.0
                                        shadowOpacity: 0.4 + 0.5 * clockRow.pulse
                                        shadowHorizontalOffset: 0
                                        shadowVerticalOffset: 0
                                    }

                                    Text {
                                        text: Qt.formatDateTime(clock.date, "HH")
                                        color: root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 64
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        text: ":"
                                        color: root.toneB
                                        opacity: clock.date.getSeconds() % 2 === 0 ? 1 : 0.25
                                        font.family: root.font
                                        font.pixelSize: 64
                                        font.weight: Font.Bold

                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }

                                    Text {
                                        text: Qt.formatDateTime(clock.date, "mm")
                                        color: root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 64
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                GlowText {
                                    glowColor: root.accentColor
                                    period: 3200
                                    delay: 400
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatDateTime(clock.date, "dddd, dd MMMM")
                                    color: root.accentColor
                                    font.family: root.font
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 16
                                    width: wkText.implicitWidth + 12
                                    radius: 8
                                    color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.18)
                                    border.width: 1
                                    border.color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.5)

                                    Text {
                                        id: wkText
                                        anchors.centerIn: parent
                                        text: "w" + root.isoWeek(clock.date)
                                        color: root.toneB
                                        font.family: root.font
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: lk2
                            opacity: surf.waveReveal(lk2, 700)
                            width: parent.width
                            height: 2
                            radius: 1

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.2; color: root.accentColor }
                                GradientStop { position: 0.45; color: root.toneB }
                                GradientStop { position: 0.7; color: root.accentColor }
                                GradientStop { position: 0.9; color: root.toneB }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Row {
                            id: lk3
                            opacity: surf.waveReveal(lk3, 700)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Item {
                                id: avatar
                                width: 52
                                height: 52

                                Repeater {
                                    model: 2

                                    delegate: Rectangle {
                                        id: ring

                                        required property int index

                                        anchors.centerIn: parent
                                        width: 52
                                        height: 52
                                        radius: 26
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
                                                NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.75; duration: 2600; easing.type: Easing.OutCubic }
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
                                        glowColor: root.accentColor
                                        period: 2600
                                        delay: 0
                                        anchors.centerIn: parent
                                        visible: face.status !== Image.Ready
                                        text: "󰀄"
                                        color: root.accentColor
                                        font.family: root.font
                                        font.pixelSize: 24
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                GlowText {
                                    glowColor: root.toneB
                                    period: 2800
                                    delay: 300
                                    readonly property int h: clock.date.getHours()
                                    text: (h < 5 ? "\uDB81\uDD94  night owl" : h < 12 ? "\uDB81\uDD99  good morning" : h < 18 ? "\uDB81\uDD99  good afternoon" : h < 22 ? "\uDB81\uDD9B  good evening" : "\uDB81\uDD94  good night")
                                    color: root.toneB
                                    font.family: root.font
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                GlowText {
                                    glowColor: root.accentColor
                                    period: 2400
                                    delay: 800
                                    text: root.userName
                                    color: root.titleColor
                                    font.family: root.font
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: root.busy ? "checking…" : root.failed ? "wrong password" + (root.attempts > 1 ? "  ×" + root.attempts : "") : "locked"
                                    color: root.failed ? root.failColor : root.textColor
                                    font.family: root.font
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Rectangle {
                            id: field
                            opacity: surf.waveReveal(field, 700)

                            width: parent.width
                            height: 38
                            radius: 8
                            color: root.cardColor
                            border.width: 1
                            border.color: root.failed ? root.failColor
                                         : root.busy ? root.accentColor
                                         : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, root.pw.length > 0 ? 0.9 : 0.45)

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            property real shakeX: 0

                            transform: Translate { x: field.shakeX }

                            SequentialAnimation {
                                id: shake
                                NumberAnimation { target: field; property: "shakeX"; to: -9; duration: 50 }
                                NumberAnimation { target: field; property: "shakeX"; to: 9; duration: 70 }
                                NumberAnimation { target: field; property: "shakeX"; to: -6; duration: 60 }
                                NumberAnimation { target: field; property: "shakeX"; to: 6; duration: 60 }
                                NumberAnimation { target: field; property: "shakeX"; to: 0; duration: 50 }
                            }

                            Connections {
                                target: root
                                function onShakeTickChanged() { shake.restart() }
                            }

                            GlowText {
                                glowColor: root.accentColor
                                period: 2400
                                delay: 0
                                anchors.centerIn: parent
                                visible: root.pw.length === 0
                                text: "󰌾  password"
                                color: root.mutedColor
                                font.family: root.font
                                font.pixelSize: 11
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Repeater {
                                    model: Math.min(root.pw.length, 22)

                                    delegate: Rectangle {
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        required property int index
                                        color: root.failed ? root.failColor : root.tonePalette[index % root.tonePalette.length]
                                        scale: 0.3

                                        Component.onCompleted: scale = 1

                                        Behavior on scale {
                                            NumberAnimation { duration: 110; easing.type: Easing.OutBack }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: lk5
                            opacity: surf.waveReveal(lk5, 700)
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "enter to unlock  ·  esc to clear"
                            color: root.mutedColor
                            font.family: root.font
                            font.pixelSize: 9
                        }

                        Row {
                            id: lk6
                            opacity: surf.waveReveal(lk6, 700)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 7

                            Repeater {
                                model: root.tonePalette

                                delegate: Rectangle {
                                    id: hd

                                    required property int index
                                    required property color modelData

                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: hd.modelData

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        PauseAnimation { duration: hd.index * 260 }
                                        NumberAnimation { from: 0.35; to: 1; duration: 700; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                                        PauseAnimation { duration: (5 - hd.index) * 260 }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: sysCard

                    visible: surf.width >= 1100
                    width: 250
                    height: sysCol.implicitHeight + 32
                    anchors.right: panel.left
                    anchors.rightMargin: 30
                    anchors.top: panel.top
                    radius: 12
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))
                    opacity: surf.waveReveal(sysCard, 700)
                    scale: 0.78 + 0.22 * Math.min(1, surf.spread)
                    transform: Translate { id: sysShift; x: -70 * (1 - surf.spread); y: 0 }

                    GradBorder {
                        rr: 12
                        c1: root.accentColor
                        c2: root.toneB
                        c3: root.accentColor
                        c4: root.toneB
                        cycle: 12000
                    }

                    Column {
                        id: sysCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 12

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "  system"
                                color: root.titleColor
                                font.family: root.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: upText.implicitWidth + 14
                                radius: 2
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)

                                Text {
                                    id: upText
                                    anchors.centerIn: parent
                                    text: "󰅐 " + root.fmtUp(root.uptimeSec)
                                    color: root.accentColor
                                    font.family: root.font
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
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

                        Repeater {
                            model: root.sysRows()

                            delegate: Column {
                                id: row

                                required property var modelData

                                width: sysCol.width
                                spacing: 5

                                Item {
                                    width: parent.width
                                    height: 14

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.modelData.icon + "  " + row.modelData.name
                                        color: row.modelData.a
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(row.modelData.v) + "%"
                                        color: root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: root.cardColor

                                    Rectangle {
                                        height: parent.height
                                        radius: 3
                                        width: Math.max(6, parent.width * Math.min(100, row.modelData.v) / 100)

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: row.modelData.a }
                                            GradientStop { position: 1.0; color: row.modelData.b }
                                        }

                                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 8

                            Rectangle {
                                visible: root.wifi !== ""
                                height: 20
                                width: wifiText.implicitWidth + 16
                                radius: 2
                                color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.5)

                                Text {
                                    id: wifiText
                                    anchors.centerIn: parent
                                    text: "󰖩 " + (root.wifi.length > 12 ? root.wifi.slice(0, 11) + "…" : root.wifi)
                                    color: root.toneB
                                    font.family: root.font
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }

                            Rectangle {
                                visible: root.vol >= 0
                                height: 20
                                width: volText.implicitWidth + 16
                                radius: 2
                                color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.5)

                                Text {
                                    id: volText
                                    anchors.centerIn: parent
                                    text: "󰕾 " + root.vol + "%"
                                    color: root.toneB
                                    font.family: root.font
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: dayCard

                    visible: surf.width >= 1100
                    width: 270
                    height: dayCol.implicitHeight + 32
                    anchors.left: panel.right
                    anchors.leftMargin: 30
                    anchors.top: panel.top
                    radius: 12
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))
                    opacity: surf.waveReveal(dayCard, 700)
                    scale: 0.78 + 0.22 * Math.min(1, surf.spread)
                    transform: Translate { id: dayShift; x: 70 * (1 - surf.spread); y: 0 }

                    GradBorder {
                        rr: 12
                        c1: root.toneB
                        c2: root.toneB
                        c3: root.toneB
                        c4: root.accentColor
                        cycle: 10000
                    }

                    Column {
                        id: dayCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 12

                        Item {
                            width: parent.width
                            height: 46
                            visible: root.wxReady

                            GlowText {
                                glowColor: root.toneB
                                period: 2600
                                delay: 0
                                id: wxIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.wxReady ? root.wx.icon : ""
                                color: root.toneB
                                font.family: root.font
                                font.pixelSize: 34
                            }

                            Text {
                                id: wxTemp
                                anchors.left: wxIcon.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.wxReady ? root.wx.temp + "°" : ""
                                color: root.titleColor
                                font.family: root.font
                                font.pixelSize: 28
                                font.weight: Font.Bold
                            }

                            Column {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                GlowText {
                                    glowColor: root.accentColor
                                    period: 3200
                                    delay: 600
                                    anchors.right: parent.right
                                    text: root.wxReady ? root.wx.cond : ""
                                    color: root.accentColor
                                    font.family: root.font
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: root.wxReady ? root.wx.city : ""
                                    color: root.textColor
                                    font.family: root.font
                                    font.pixelSize: 9
                                }

                                Text {
                                    anchors.right: parent.right
                                    text: root.wxReady ? "H " + root.wx.max + "°  L " + root.wx.min + "°" : ""
                                    color: root.mutedColor
                                    font.family: root.font
                                    font.pixelSize: 9
                                }
                            }
                        }

                        Row {
                            visible: root.wxReady
                            spacing: 6

                            Repeater {
                                model: root.wxReady ? [
                                    { k: "feels", v: root.wx.feels + "°", c: root.toneB },
                                    { k: "humid", v: root.wx.humidity + "%", c: root.toneB },
                                    { k: "wind", v: root.wx.wind + "km/h", c: root.accentColor },
                                    { k: "rain", v: root.wx.rain + "%", c: root.accentColor }
                                ] : []

                                delegate: Rectangle {
                                    id: chip

                                    required property var modelData

                                    height: 34
                                    width: (dayCol.width - 18) / 4
                                    radius: 8
                                    color: Qt.rgba(chip.modelData.c.r, chip.modelData.c.g, chip.modelData.c.b, 0.14)
                                    border.width: 1
                                    border.color: Qt.rgba(chip.modelData.c.r, chip.modelData.c.g, chip.modelData.c.b, 0.4)

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: chip.modelData.v
                                            color: root.titleColor
                                            font.family: root.font
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: chip.modelData.k
                                            color: chip.modelData.c
                                            font.family: root.font
                                            font.pixelSize: 8
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: root.wxReady
                            width: parent.width
                            height: 2
                            radius: 1

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.3; color: root.toneB }
                                GradientStop { position: 0.6; color: root.toneB }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: Qt.formatDateTime(clock.date, "MMMM yyyy").toLowerCase()
                                color: root.titleColor
                                font.family: root.font
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "week " + root.isoWeek(clock.date)
                                color: root.toneB
                                font.family: root.font
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }

                        Row {
                            spacing: 4

                            Repeater {
                                model: root.weekDays(clock.date)

                                delegate: Rectangle {
                                    id: wd

                                    required property var modelData

                                    readonly property bool today: wd.modelData.d.getDate() === clock.date.getDate() && wd.modelData.d.getMonth() === clock.date.getMonth()
                                    readonly property bool weekend: wd.modelData.idx >= 5

                                    width: (dayCol.width - 24) / 7
                                    height: 44
                                    radius: 2
                                    color: wd.today ? "transparent" : root.cardColor
                                    border.width: wd.today ? 0 : 1
                                    border.color: wd.weekend ? Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.5) : root.lineColor

                                    gradient: wd.today ? todayGrad : null

                                    Gradient {
                                        id: todayGrad
                                        GradientStop { position: 0.0; color: root.accentColor }
                                        GradientStop { position: 1.0; color: root.toneB }
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: Qt.formatDateTime(wd.modelData.d, "ddd").slice(0, 2).toLowerCase()
                                            color: wd.today ? root.inkColor : wd.weekend ? root.toneB : root.mutedColor
                                            font.family: root.font
                                            font.pixelSize: 8
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: wd.modelData.d.getDate()
                                            color: wd.today ? root.inkColor : root.titleColor
                                            font.family: root.font
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            visible: root.wxReady
                            spacing: 6

                            Repeater {
                                model: root.wxReady ? root.wx.hourly.slice(0, 5) : []

                                delegate: Column {
                                    id: hr

                                    required property var modelData

                                    width: (dayCol.width - 24) / 5
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: hr.modelData.t
                                        color: root.mutedColor
                                        font.family: root.font
                                        font.pixelSize: 8
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: hr.modelData.icon
                                        color: root.toneB
                                        font.family: root.font
                                        font.pixelSize: 15
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: hr.modelData.temp + "°"
                                        color: root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: calCard

                    visible: dayCard.visible
                    width: 270
                    height: calCol.implicitHeight + 32
                    anchors.left: panel.right
                    anchors.leftMargin: 30
                    anchors.top: dayCard.bottom
                    anchors.topMargin: 14
                    radius: 12
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))
                    opacity: surf.waveReveal(calCard, 700)
                    scale: 0.78 + 0.22 * Math.min(1, surf.spread)
                    transform: Translate { id: calShift; x: 70 * (1 - surf.spread); y: 0 }

                    GradBorder {
                        rr: 12
                        c1: root.accentColor
                        c2: root.toneB
                        c3: root.accentColor
                        c4: root.toneB
                        cycle: 13000
                    }

                    Column {
                        id: calCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 10

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uDB80\uDCED  calendar"
                                color: root.titleColor
                                font.family: root.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: calMonth.implicitWidth + 14
                                radius: 2
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)

                                Text {
                                    id: calMonth
                                    anchors.centerIn: parent
                                    text: Qt.formatDateTime(clock.date, "MMM yyyy").toLowerCase()
                                    color: root.accentColor
                                    font.family: root.font
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
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

                        Row {
                            spacing: 4

                            Repeater {
                                model: ["mo", "tu", "we", "th", "fr", "sa", "su"]

                                delegate: Text {
                                    id: calHead

                                    required property string modelData
                                    required property int index

                                    width: (calCol.width - 24) / 7
                                    horizontalAlignment: Text.AlignHCenter
                                    text: calHead.modelData
                                    color: calHead.index >= 5 ? root.toneB : root.mutedColor
                                    font.family: root.font
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Grid {
                            columns: 7
                            spacing: 4

                            Repeater {
                                model: root.monthCells(clock.date)

                                delegate: Rectangle {
                                    id: cd

                                    required property var modelData

                                    readonly property bool today: cd.modelData.on && cd.modelData.n === clock.date.getDate()

                                    width: (calCol.width - 24) / 7
                                    height: 22
                                    radius: 6
                                    color: "transparent"
                                    gradient: cd.today ? calGrad : null

                                    Gradient {
                                        id: calGrad
                                        GradientStop { position: 0.0; color: root.accentColor }
                                        GradientStop { position: 1.0; color: root.toneB }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: cd.modelData.on
                                        text: cd.modelData.n
                                        color: cd.today ? root.inkColor : cd.modelData.we ? root.toneB : root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: cd.today ? Font.Bold : Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: greetBox

                    z: 100
                    visible: surf.height >= 700
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: panel.top
                    anchors.bottomMargin: 22
                    spacing: 8
                    opacity: surf.waveReveal(greetBox, 700)
                    scale: 0.78 + 0.22 * Math.min(1, surf.spread)
                    transform: Translate { id: greetShift; y: 24 * (1 - surf.spread) }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        id: greetText
                        text: root.greeting(clock.date)
                        color: root.titleColor

                        property real pulse: 0

                        SequentialAnimation on pulse {
                            loops: Animation.Infinite
                            PauseAnimation { duration: 600 }
                            NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutSine }
                        }

                        font.family: root.font
                        font.pixelSize: 20
                        font.weight: Font.Bold

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.clockGlow
                            shadowBlur: 1.0
                            shadowOpacity: 0.4 + 0.5 * greetText.pulse
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 160
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
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 420
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.quotes[root.quoteIdx]
                        color: root.accentColor
                        font.family: root.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: notifCard

                    visible: sysCard.visible && root.notifs.length > 0
                    width: 250
                    height: notifCol.implicitHeight + 32
                    anchors.right: panel.left
                    anchors.rightMargin: 30
                    anchors.top: sysCard.bottom
                    anchors.topMargin: 14
                    radius: 12
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))
                    opacity: surf.waveReveal(notifCard, 700)
                    scale: 0.78 + 0.22 * Math.min(1, surf.spread)
                    transform: Translate { id: notifShift; x: -70 * (1 - surf.spread); y: 0 }

                    GradBorder {
                        rr: 12
                        c1: root.toneB
                        c2: root.accentColor
                        c3: root.toneB
                        c4: root.accentColor
                        cycle: 11000
                    }

                    Column {
                        id: notifCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 12

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uDB80\uDC9A  notifications"
                                color: root.titleColor
                                font.family: root.font
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: nCount.implicitWidth + 14
                                radius: 8
                                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                border.width: 1
                                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)

                                Text {
                                    id: nCount
                                    anchors.centerIn: parent
                                    text: root.notifs.length
                                    color: root.accentColor
                                    font.family: root.font
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
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

                        Repeater {
                            model: root.notifs.slice(0, 3)

                            delegate: Column {
                                id: nItem

                                required property var modelData

                                width: notifCol.width
                                spacing: 5

                                Item {
                                    width: parent.width
                                    height: 14

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: nTime.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: nItem.modelData.app
                                        color: root.accentColor
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        id: nTime
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: nItem.modelData.time
                                        color: root.titleColor
                                        font.family: root.font
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: nItem.modelData.title
                                    color: root.textColor
                                    font.family: root.font
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                Row {
                    id: powerRow

                    opacity: surf.waveReveal(powerRow, 700)
                    z: 100
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: media.visible ? media.bottom : panel.bottom
                    anchors.topMargin: 14
                    spacing: 10

                    Repeater {
                        model: [
                            { glyph: "󰖔", act: "suspend", tint: root.toneB },
                            { glyph: "󰐥", act: "poweroff", tint: root.toneB },
                            { glyph: "󰜉", act: "reboot", tint: root.toneB }
                        ]

                        delegate: Rectangle {
                            id: pb

                            required property var modelData

                            width: 44
                            height: 30
                            radius: 9
                            color: root.inkColor
                            border.width: 1
                            border.color: Qt.rgba(pb.modelData.tint.r, pb.modelData.tint.g, pb.modelData.tint.b, pArea.containsMouse ? 0.9 : 0.45)
                            scale: pArea.containsMouse ? 1.08 : 1

                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(pb.modelData.tint.r, pb.modelData.tint.g, pb.modelData.tint.b, pArea.containsMouse ? 0.35 : 0.14)

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: pb.modelData.glyph
                                color: pb.modelData.tint
                                font.family: root.font
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: pArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", pb.modelData.act])
                            }
                        }
                    }
                }

                Rectangle {
                    id: media

                    visible: root.player !== null
                    width: 340
                    height: 100
                    opacity: surf.waveReveal(media, 700)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: panel.bottom
                    anchors.topMargin: 14
                    radius: 10
                    color: root.panelColor
                    border.width: 1
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))

                    GradBorder {
                        rr: 10
                        c1: root.toneB
                        c2: root.accentColor
                        c3: root.toneB
                        c4: root.accentColor
                        cycle: 11000
                    }

                    Glow {
                        width: 190; height: 190
                        x: 12 + 38 - 95
                        anchors.verticalCenter: parent.verticalCenter
                        tint: root.accentColor
                        strength: 0.35
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        height: 16
                        spacing: 3

                        Repeater {
                            model: 4

                            delegate: Rectangle {
                                id: eq

                                required property int index

                                width: 3
                                radius: 1.5
                                anchors.bottom: parent.bottom
                                height: 4
                                color: root.tonePalette[index]

                                SequentialAnimation on height {
                                    running: root.player !== null && root.player.isPlaying
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 16; duration: 260 + eq.index * 90; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 5; duration: 300 + eq.index * 70; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 11; duration: 220 + eq.index * 60; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 4; duration: 280 + eq.index * 80; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: art

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 76
                        height: 76
                        radius: 8
                        clip: true
                        color: root.cardColor

                        Image {
                            id: cover
                            anchors.fill: parent
                            source: root.player ? root.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 400
                            sourceSize.height: 400
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cover.status !== Image.Ready
                            text: "󰀥"
                            color: root.accentColor
                            font.family: root.font
                            font.pixelSize: 28
                        }
                    }

                    Column {
                        anchors.left: art.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 40
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        spacing: 2

                        Text {
                            width: parent.width
                            text: root.player ? root.player.trackTitle : ""
                            color: root.titleColor
                            font.family: root.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        GlowText {
                            glowColor: root.accentColor
                            period: 3000
                            delay: 200
                            width: parent.width
                            text: root.player ? root.player.trackArtist : ""
                            color: root.accentColor
                            font.family: root.font
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: seek

                        anchors.left: art.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 38
                        height: 10

                        readonly property real len: root.pcOk ? root.pcLen : (root.player ? root.player.length : 0)
                        readonly property real pos: root.pcOk ? root.pcPos : (root.player ? root.player.position : 0)
                        property bool dragging: false
                        property real dragRatio: 0

                        onDraggingChanged: root.seekBusy = dragging

                        Timer {
                            id: settle
                            interval: 700
                            onTriggered: {
                                seek.dragging = false
                                if (!pcProc.running)
                                    pcProc.running = true
                            }
                        }
                        readonly property real ratio: dragging ? dragRatio : (len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 3
                            height: 4
                            radius: 2
                            color: root.cardColor

                            Rectangle {
                                id: fill
                                width: parent.width * seek.ratio
                                height: parent.height
                                radius: 3

                                Behavior on width {
                                    enabled: !seek.dragging
                                    NumberAnimation { duration: 900 }
                                }

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.accentColor }
                                    GradientStop { position: 1.0; color: root.toneB }
                                }
                            }

                            Rectangle {
                                x: Math.max(0, fill.width - 4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: root.titleColor
                                visible: seek.len > 0
                            }

                            MouseArea {
                                id: seekArea

                                anchors.fill: parent
                                anchors.topMargin: -6
                                anchors.bottomMargin: -6
                                enabled: root.player !== null && root.player.canSeek && seek.len > 0
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true

                                function ratioAt(x) {
                                    return Math.max(0, Math.min(1, x / width))
                                }

                                onPressed: mouse => {
                                    settle.stop()
                                    seek.dragRatio = seekArea.ratioAt(mouse.x)
                                    seek.dragging = true
                                }

                                onPositionChanged: mouse => {
                                    if (seek.dragging)
                                        seek.dragRatio = seekArea.ratioAt(mouse.x)
                                }

                                onReleased: mouse => {
                                    if (!seek.dragging)
                                        return
                                    var r = seekArea.ratioAt(mouse.x)
                                    seek.dragRatio = r
                                    if (root.player && seek.len > 0) {
                                        var cmd = ["playerctl"]
                                        var name = root.player.dbusName ? String(root.player.dbusName).replace("org.mpris.MprisPlayer2.", "") : ""
                                        if (name !== "")
                                            cmd.push("-p", name)
                                        var target = Math.min(r, 0.995) * seek.len
                                        cmd.push("position", target.toFixed(2))
                                        Quickshell.execDetached(cmd)
                                        root.pcPos = target
                                    }
                                    settle.restart()
                                }

                                onCanceled: seek.dragging = false
                            }
                        }
                    }

                    Row {
                        anchors.left: art.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        spacing: 5

                        Repeater {
                            model: [
                                { glyph: "󰒝", act: "shuffle" },
                                { glyph: "󰒮", act: "prev" },
                                { glyph: "", act: "play" },
                                { glyph: "󰒭", act: "next" },
                                { glyph: "󰑖", act: "loop" }
                            ]

                            delegate: Rectangle {
                                id: btn

                                required property var modelData

                                readonly property bool main: btn.modelData.act === "play"
                                readonly property bool on:
                                    root.player !== null
                                    && ((btn.modelData.act === "shuffle" && root.player.shuffle)
                                        || (btn.modelData.act === "loop" && root.player.loopState !== MprisLoopState.None))

                                width: btn.main ? 34 : 24
                                height: 24
                                radius: 8
                                color: btn.main
                                       ? root.accentColor
                                       : btn.on
                                         ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                                         : area.containsMouse ? root.lineColor : root.cardColor

                                Text {
                                    anchors.centerIn: parent
                                    text: btn.main
                                          ? (root.player && root.player.isPlaying ? "󰏤" : "󰐊")
                                          : btn.modelData.act === "loop" && root.player
                                            ? (root.player.loopState === MprisLoopState.Track ? "󰑘"
                                               : root.player.loopState === MprisLoopState.None ? "󰑗" : "󰑖")
                                            : btn.modelData.glyph
                                    color: btn.main ? root.inkColor : root.titleColor
                                    font.family: root.font
                                    font.pixelSize: btn.main ? 14 : 11
                                }

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        var p = root.player
                                        var a = btn.modelData.act

                                        if (!p) return

                                        if (a === "play")
                                            p.togglePlaying()
                                        else if (a === "prev")
                                            p.previous()
                                        else if (a === "next")
                                            p.next()
                                        else if (a === "shuffle" && p.shuffleSupported)
                                            p.shuffle = !p.shuffle
                                        else if (a === "loop" && p.loopSupported)
                                            p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                                        : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                                        : MprisLoopState.None
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: waveFx

                readonly property real reach: Math.hypot(surf.width, surf.height) * 1.02
                readonly property real core: 0
                readonly property real hole: core + (reach - core) * surf.open

                anchors.fill: parent
                visible: false

                Rectangle {
                    visible: wall.status !== Image.Ready
                    readonly property real cover: Math.max(0, (waveFx.reach - waveFx.hole) / 2)

                    width: waveFx.reach
                    height: waveFx.reach
                    radius: width / 2
                    x: (surf.width - width) / 2
                    y: (surf.height - height) / 2
                    color: "transparent"
                    border.width: cover
                    border.color: root.backdropColor
                }

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        id: ring

                        required property int index

                        readonly property real diameter: Math.max(0, waveFx.hole - ring.index * 90)

                        width: diameter
                        height: diameter
                        radius: diameter / 2
                        x: (surf.width - diameter) / 2
                        y: (surf.height - diameter) / 2
                        color: "transparent"
                        border.width: 3 - ring.index * 0.8
                        border.color: ring.index === 0 ? root.accentColor : ring.index === 1 ? root.hueB : root.hueC
                        opacity: (0.9 - ring.index * 0.2) * Math.min(1, (1 - surf.open) * 8)
                        visible: diameter > 4
                    }
                }
            }
        }
    }
}
