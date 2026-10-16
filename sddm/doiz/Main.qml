import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtMultimedia

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#060d10"

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property color panelColor: config.panel ? config.panel : "#8c0b1519"
    readonly property color cardColor: config.card ? config.card : "#26000000"
    readonly property color accentColor: config.accent ? config.accent : "#5fd3bc"
    readonly property color titleColor: config.title ? config.title : "#e3f1ee"
    readonly property color textColor: config.text ? config.text : "#9db5b2"
    readonly property color mutedColor: config.muted ? config.muted : "#5f7776"
    readonly property color failColor: config.fail ? config.fail : "#d9778f"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    readonly property bool glowOn: config.glow !== "false"
    readonly property color edgeColor: config.edge ? config.edge : "#42a2d3"
    readonly property color edgeAlt: config.edgeAlt ? config.edgeAlt : "#aea5f0"
    readonly property color glassBase: config.glass ? config.glass : "#0f2230"
    readonly property real glassAlpha: config.glassAlpha ? Number(config.glassAlpha) : 0
    readonly property color glassTint: Qt.rgba(glassBase.r, glassBase.g, glassBase.b, glassAlpha)

    property int attempts: 0
    property bool busy: false
    property real todayPulse: 0

    SequentialAnimation on todayPulse {
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutSine }
    }
    property bool failed: false
    property bool reveal: false
    property real open: 0
    property date now: new Date()
    property var wx: null
    property var wxLoc: null
    property bool wxBusy: false
    readonly property bool wxReady: wx !== null && wx.ok === true
    readonly property color inkColor: "#0b1519"
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
    property string faceHome: ""
    property string faceIcon: ""

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function weekInfo() {
        var d = now
        var start = new Date(d.getFullYear(), 0, 1)
        var doy = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - start) / 86400000) + 1
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var dn = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - dn)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        var wk = Math.ceil(((t - y0) / 86400000 + 1) / 7)
        return "Week " + wk + "  \u00b7  Day " + doy
    }

    function greeting() {
        var h = now.getHours()
        if (h < 5)
            return "\uDB81\uDD94  night owl"
        if (h < 12)
            return "\uDB81\uDD99  good morning"
        if (h < 18)
            return "\uDB81\uDD99  good afternoon"
        if (h < 22)
            return "\uDB81\uDD9B  good evening"
        return "\uDB81\uDD94  good night"
    }

    function layoutName() {
        if (typeof keyboard === "undefined" || !keyboard || !keyboard.layouts || keyboard.layouts.length === 0)
            return ""
        var l = keyboard.layouts[keyboard.currentLayout]
        return l && l.shortName ? l.shortName : ""
    }

    function monthCells() {
        var d = now
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

    function greetFull() {
        var h = now.getHours()
        var t = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
        return t + (user.text.length > 0 ? ", " + user.text : "")
    }

    function doy() {
        var d = now
        return Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1
    }

    function progress(k) {
        var d = now
        var day = (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400
        if (k === 0)
            return day
        if (k === 1)
            return ((d.getDay() + 6) % 7 + day) / 7
        if (k === 2)
            return (d.getDate() - 1 + day) / new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        var start = new Date(d.getFullYear(), 0, 1)
        var doy = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - start) / 86400000)
        var len = new Date(d.getFullYear(), 11, 31).getTime() - start.getTime()
        return (doy + day) / (Math.round(len / 86400000) + 1)
    }

    function cp(n) {
        n -= 0x10000
        return String.fromCharCode(0xD800 + (n >> 10), 0xDC00 + (n & 0x3ff))
    }

    function wxKind(code, day) {
        if (code === 0)
            return [cp(day ? 0xF0599 : 0xF0594), "Clear"]
        if (code === 1 || code === 2)
            return [cp(0xF0595), "Partly cloudy"]
        if (code === 3)
            return [cp(0xF0590), "Overcast"]
        if (code === 45 || code === 48)
            return [cp(0xF0591), "Fog"]
        if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].indexOf(code) >= 0)
            return [cp(0xF0597), code < 58 ? "Drizzle" : "Rain"]
        if ([71, 73, 75, 77, 85, 86].indexOf(code) >= 0)
            return [cp(0xF0598), "Snow"]
        if (code === 95 || code === 96 || code === 99)
            return [cp(0xF0593), "Thunderstorm"]
        return [cp(0xF0590), "Unknown"]
    }

    function wxGet(url, cb) {
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== 4)
                return
            if (x.status !== 200) {
                cb(null)
                return
            }
            try {
                cb(JSON.parse(x.responseText))
            } catch (e) {
                cb(null)
            }
        }
        x.open("GET", url)
        x.send()
    }

    function wxBuild(loc, raw) {
        var cur = raw.current, hr = raw.hourly, dy = raw.daily
        var k = wxKind(cur.weather_code, cur.is_day !== 0)
        var nowH = cur.time.slice(0, 13)
        var start = 0
        for (var i = 0; i < hr.time.length; i++) {
            if (hr.time[i].slice(0, 13) >= nowH) {
                start = i
                break
            }
        }
        var hourly = []
        for (var j = start + 1; j < Math.min(start + 7, hr.time.length); j++)
            hourly.push({ t: hr.time[j].slice(11, 16), icon: wxKind(hr.weather_code[j], hr.is_day[j] !== 0)[0], temp: Math.round(hr.temperature_2m[j]) })
        return {
            ok: true,
            city: loc.city || "Unknown",
            icon: k[0],
            cond: k[1],
            temp: Math.round(cur.temperature_2m),
            feels: Math.round(cur.apparent_temperature),
            humidity: Math.round(cur.relative_humidity_2m),
            wind: Math.round(cur.wind_speed_10m),
            min: Math.round(dy.temperature_2m_min[0]),
            max: Math.round(dy.temperature_2m_max[0]),
            rain: dy.precipitation_probability_max[0] || 0,
            hourly: hourly
        }
    }

    function wxFetch(loc) {
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + loc.latitude + "&longitude=" + loc.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&timezone=auto&forecast_days=2&wind_speed_unit=kmh"
        wxGet(url, function (raw) {
            root.wxBusy = false
            if (raw && raw.current)
                root.wx = wxBuild(loc, raw)
        })
    }

    function wxRefresh() {
        if (wxBusy)
            return
        wxBusy = true
        if (wxLoc) {
            wxFetch(wxLoc)
            return
        }
        wxGet("https://ipwho.is/", function (l) {
            if (!l || l.success === false || l.latitude === undefined) {
                root.wxBusy = false
                return
            }
            root.wxLoc = l
            root.wxFetch(l)
        })
    }

    function weekDays() {
        var d = now
        var mon = new Date(d.getFullYear(), d.getMonth(), d.getDate() - ((d.getDay() + 6) % 7))
        var out = []
        for (var i = 0; i < 7; i++) {
            var x = new Date(mon.getFullYear(), mon.getMonth(), mon.getDate() + i)
            out.push({ n: x.getDate(), idx: i, today: x.getDate() === d.getDate() && x.getMonth() === d.getMonth(), name: Qt.formatDate(x, "ddd").slice(0, 2).toLowerCase() })
        }
        return out
    }

    function isoWeek() {
        var d = now
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var dn = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - dn)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil(((t - y0) / 86400000 + 1) / 7)
    }

    function doLogin() {
        if (busy)
            return
        busy = true
        failed = false
        sddm.login(user.text, pass.text, session.currentIndex)
    }

    component GlowText: Item {
        id: gt

        property alias text: main.text
        property alias color: main.color
        property alias font: main.font
        property alias elide: main.elide
        property alias topPadding: main.topPadding
        property alias horizontalAlignment: main.horizontalAlignment
        property color glowColor: root.accentColor
        property bool blink: true
        property int period: 2400
        property int delay: 0
        property bool icon: false
        property real minGlow: icon ? 0.08 : 0.25
        property real pulse: blink ? minGlow : 1

        implicitWidth: main.implicitWidth
        implicitHeight: main.implicitHeight
        opacity: blink ? (icon ? 0.4 + 0.6 * pulse : 0.62 + 0.38 * pulse) : 1

        Text {
            id: halo

            visible: root.glowOn
            width: gt.width
            text: main.text
            color: main.color
            font: main.font
            elide: main.elide
            topPadding: main.topPadding
            horizontalAlignment: main.horizontalAlignment

            layer.enabled: root.glowOn
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: gt.glowColor
                shadowBlur: 1.0
                shadowOpacity: gt.pulse
                shadowScale: gt.icon ? 1.35 : 1.0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Text {
            id: main

            width: gt.width
        }

        SequentialAnimation {
            running: gt.blink
            loops: Animation.Infinite

            PauseAnimation { duration: gt.delay }
            NumberAnimation { target: gt; property: "pulse"; to: 1; duration: gt.period / 2; easing.type: Easing.InOutSine }
            NumberAnimation { target: gt; property: "pulse"; to: gt.minGlow; duration: gt.period / 2; easing.type: Easing.InOutSine }
        }
    }

    component DField: TextField {
        id: tf

        property string icon: ""
        property bool bad: false

        height: 32
        leftPadding: 42
        rightPadding: 42
        color: root.titleColor
        placeholderTextColor: root.mutedColor
        selectionColor: root.accentColor
        selectedTextColor: "#0b1519"
        font.family: root.mono
        font.pixelSize: 11
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter

        background: Rectangle {
            radius: 8
            color: root.cardColor
            border.width: 1
            border.color: tf.bad ? root.failColor : root.tint(root.edgeColor, tf.activeFocus ? 0.9 : 0.45)

            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        GlowText {
            icon: true
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            text: tf.icon
            period: 2800
            glowColor: tf.bad ? root.failColor : root.accentColor
            color: tf.bad ? root.failColor : root.accentColor
            font.family: root.mono
            font.pixelSize: 14
        }
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

    component Frost: Item {
        property real rr: 11

        anchors.fill: parent
        anchors.margins: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.rr
            color: root.glassTint
        }
    }

    component Chip: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""
        property color tone: root.accentColor
        signal clicked()

        height: 32
        width: chipRow.implicitWidth + 28
        radius: 8
        color: "transparent"
        border.width: 1
        border.color: root.tint(chip.tone === root.accentColor ? root.edgeColor : chip.tone, chipArea.containsMouse ? 0.8 : 0.35)

        Frost { rr: 7 }

        Behavior on border.color { ColorAnimation { duration: 120 } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8

            GlowText {
                icon: true
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                glowColor: chip.tone
                period: 3000
                color: chip.tone
                font.family: root.mono
                font.pixelSize: 14
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: root.textColor
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    component PowerBtn: Rectangle {
        id: pb

        property string glyph: ""
        signal clicked()

        width: 56
        height: 36
        radius: 8
        color: pbArea.containsMouse ? root.tint(root.accentColor, 0.14) : root.panelColor
        border.width: 1
        border.color: root.tint(root.edgeColor, pbArea.containsMouse ? 0.9 : 0.4)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: pb.glyph
            color: pbArea.containsMouse ? root.accentColor : root.titleColor
            font.family: root.mono
            font.pixelSize: 16
        }

        MouseArea {
            id: pbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    Item {
        id: bgLayer
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl(config.poster)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        VideoOutput {
            id: video
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
        }
    }

    MediaPlayer {
        id: player
        source: Qt.resolvedUrl(config.background)
        loops: MediaPlayer.Infinite
        videoOutput: video
        Component.onCompleted: player.play()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    NumberAnimation {
        id: openAnim
        target: root
        property: "open"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.OutCubic
    }


    Row {
        x: 48
        y: 40
        spacing: 10
        opacity: root.open

        Chip {
            icon: "\uDB80\uDF22"
            label: sddm.hostName
            visible: sddm.hostName.length > 0
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 48
        y: 40
        spacing: 10
        opacity: root.open

        Chip {
            icon: "\uDB81\uDE32"
            label: "caps lock"
            tone: root.failColor
            visible: typeof keyboard !== "undefined" && keyboard && keyboard.capsLock
        }

        Chip {
            icon: "\uDB80\uDF0C"
            label: root.layoutName()
            visible: root.layoutName().length > 0
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }

    Column {
        id: lstack
        width: 320
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 10
        opacity: root.open
        transform: Translate { x: 24 * (1 - root.open) }


    Rectangle {
        id: calCard
        width: parent.width
        height: calCol.implicitHeight + 24
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.tint(root.edgeColor, 0.75)

        Frost {}

        GradBorder {
            rr: 12
            c1: root.edgeColor
            c2: root.edgeAlt
            c3: root.edgeColor
            c4: root.edgeAlt
            cycle: 13000
        }

        Column {
            id: calCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 7

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    GlowText {
                        icon: true
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.cp(0xF00ED)
                        period: 3000
                        delay: 0
                        glowColor: root.accentColor
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "calendar"
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    width: calMonth.implicitWidth + 14
                    radius: 2
                    color: root.tint(root.accentColor, 0.16)
                    border.width: 1
                    border.color: root.tint(root.edgeColor, 0.5)

                    Text {
                        id: calMonth
                        anchors.centerIn: parent
                        text: Qt.formatDate(root.now, "MMM yyyy").toLowerCase()
                        color: root.accentColor
                        font.family: root.mono
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
                        font.family: root.mono
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }

            Grid {
                columns: 7
                spacing: 4

                Repeater {
                    model: root.monthCells()

                    delegate: Rectangle {
                        id: cd
                        required property var modelData

                        readonly property bool today: cd.modelData.on && cd.modelData.n === root.now.getDate()

                        width: (calCol.width - 24) / 7
                        height: 22
                        radius: 6
                        color: "transparent"
                        gradient: cd.today ? calGrad : null

                        layer.enabled: cd.today && root.glowOn
                        layer.effect: MultiEffect {
                            autoPaddingEnabled: true
                            shadowEnabled: true
                            shadowColor: root.accentColor
                            shadowBlur: 1.0
                            shadowOpacity: 0.35 + 0.55 * root.todayPulse
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

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
                            font.family: root.mono
                            font.pixelSize: 10
                            font.weight: cd.today ? Font.Bold : Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    }

    Glow {
        visible: root.glowOn
        width: 620; height: 620
        anchors.centerIn: stack
        tint: root.accentColor
        strength: 0.4
        opacity: root.open
        SequentialAnimation on opacity { loops: Animation.Infinite
            NumberAnimation { from: 0.45; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.45; duration: 2600; easing.type: Easing.InOutSine } }
    }

    Rectangle {
        id: clockCard
        x: 48
        y: 96
        width: 320
        opacity: root.open
        transform: Translate { x: -24 * (1 - root.open) }
        height: cc.implicitHeight + 16
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.tint(root.edgeColor, 0.75)

        Frost {}

        GradBorder {
            rr: 12
            c1: root.edgeColor
            c2: root.edgeAlt
            c3: root.edgeColor
            c4: root.edgeAlt
            cycle: 13000
        }

        Column {
            id: cc
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 2

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

                    layer.enabled: root.glowOn
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: true
                        shadowEnabled: true
                        shadowColor: root.accentColor
                        shadowBlur: 1.0
                        shadowOpacity: 0.4 + 0.5 * clockRow.pulse
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Text {
                        text: Qt.formatTime(root.now, "HH")
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 84
                        font.weight: Font.Bold
                    }

                    Text {
                        text: ":"
                        color: root.toneB
                        opacity: root.now.getSeconds() % 2 === 0 ? 1 : 0.25
                        font.family: root.mono
                        font.pixelSize: 84
                        font.weight: Font.Bold

                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    Text {
                        text: Qt.formatTime(root.now, "mm")
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 84
                        font.weight: Font.Bold
                    }
                }
            }

            GlowText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
                period: 3200
                delay: 400
                color: root.accentColor
                font.family: root.mono
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            GlowText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.weekInfo()
                period: 3600
                delay: 800
                glowColor: root.toneB
                color: root.toneB
                font.family: root.mono
                font.pixelSize: 11
            }
        }
    }

    Rectangle {
        id: dayCard
        x: root.width - 48 - width
        y: clockCard.y
        width: 320
        opacity: root.open
        transform: Translate { y: -24 * (1 - root.open) }
        height: dc.implicitHeight + 24
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.tint(root.edgeColor, 0.75)

        Frost {}

        GradBorder {
            rr: 12
            c1: root.edgeAlt
            c2: root.edgeAlt
            c3: root.edgeAlt
            c4: root.edgeColor
            cycle: 10000
        }

        Column {
            id: dc
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 46
                visible: root.wxReady

                GlowText {
                    icon: true
                    id: wxIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    glowColor: root.toneB
                    period: 2600
                    text: root.wxReady ? root.wx.icon : ""
                    color: root.toneB
                    font.family: root.mono
                    font.pixelSize: 34
                }

                Text {
                    anchors.left: wxIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wxReady ? root.wx.temp + "\u00b0" : ""
                    color: root.titleColor
                    font.family: root.mono
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    GlowText {
                        anchors.right: parent.right
                        period: 3200
                        delay: 600
                        text: root.wxReady ? root.wx.cond : ""
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.right: parent.right
                        text: root.wxReady ? root.wx.city : ""
                        color: root.textColor
                        font.family: root.mono
                        font.pixelSize: 9
                    }

                    Text {
                        anchors.right: parent.right
                        text: root.wxReady ? "H " + root.wx.max + "\u00b0  L " + root.wx.min + "\u00b0" : ""
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                }
            }

            Row {
                visible: root.wxReady
                spacing: 6

                Repeater {
                    model: root.wxReady ? [
                        { k: "feels", v: root.wx.feels + "\u00b0", c: root.toneB },
                        { k: "humid", v: root.wx.humidity + "%", c: root.toneB },
                        { k: "wind", v: root.wx.wind + "km/h", c: root.accentColor },
                        { k: "rain", v: root.wx.rain + "%", c: root.accentColor }
                    ] : []

                    delegate: Rectangle {
                        id: chipW
                        required property var modelData

                        height: 34
                        width: (dc.width - 18) / 4
                        radius: 8
                        color: root.tint(chipW.modelData.c, 0.14)
                        border.width: 1
                        border.color: root.tint(chipW.modelData.c, 0.4)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: chipW.modelData.v
                                color: root.titleColor
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: chipW.modelData.k
                                color: chipW.modelData.c
                                font.family: root.mono
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
                    text: Qt.formatDate(root.now, "MMMM yyyy").toLowerCase()
                    color: root.titleColor
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "week " + root.isoWeek()
                    color: root.toneB
                    font.family: root.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            Row {
                spacing: 4

                Repeater {
                    model: root.weekDays()

                    delegate: Rectangle {
                        id: wd
                        required property var modelData
                        readonly property bool weekend: wd.modelData.idx >= 5

                        width: (dc.width - 24) / 7
                        height: 44
                        radius: 2
                        color: wd.modelData.today ? "transparent" : root.cardColor
                        border.width: wd.modelData.today ? 0 : 1
                        border.color: wd.weekend ? root.tint(root.edgeAlt, 0.5) : root.tint(root.edgeColor, 0.35)
                        gradient: wd.modelData.today ? todayGrad : null

                        layer.enabled: wd.modelData.today && root.glowOn
                        layer.effect: MultiEffect {
                            autoPaddingEnabled: true
                            shadowEnabled: true
                            shadowColor: root.accentColor
                            shadowBlur: 1.0
                            shadowOpacity: 0.35 + 0.55 * root.todayPulse
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

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
                                text: wd.modelData.name
                                color: wd.modelData.today ? root.inkColor : wd.weekend ? root.toneB : root.mutedColor
                                font.family: root.mono
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: wd.modelData.n
                                color: wd.modelData.today ? root.inkColor : root.titleColor
                                font.family: root.mono
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
                        id: hrc
                        required property var modelData
                        required property int index

                        width: (dc.width - 24) / 5
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hrc.modelData.t
                            color: root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 8
                        }

                        GlowText {
                            icon: true
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hrc.modelData.icon
                            period: 3200
                            delay: hrc.index * 240
                            glowColor: root.toneB
                            color: root.toneB
                            font.family: root.mono
                            font.pixelSize: 15
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: hrc.modelData.temp + "\u00b0"
                            color: root.titleColor
                            font.family: root.mono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: sysCard
        x: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: clockCard.width
        opacity: root.open
        transform: Translate { x: -24 * (1 - root.open) }
        height: sysCol.implicitHeight + 24
        radius: 12
        color: "transparent"
        border.width: 1
        border.color: root.tint(root.edgeColor, 0.75)

        Frost {}

        GradBorder {
            rr: 12
            c1: root.edgeColor
            c2: root.edgeAlt
            c3: root.edgeColor
            c4: root.edgeAlt
            cycle: 12000
        }

        Column {
            id: sysCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    GlowText {
                        icon: true
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.cp(0xF0954)
                        period: 3000
                        delay: 400
                        glowColor: root.accentColor
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "time"
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    width: dayText.implicitWidth + 14
                    radius: 2
                    color: root.tint(root.accentColor, 0.16)
                    border.width: 1
                    border.color: root.tint(root.edgeColor, 0.5)

                    Row {
                        id: dayText
                        anchors.centerIn: parent
                        spacing: 4

                        GlowText {
                            icon: true
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.cp(0xF0150)
                            period: 2600
                            glowColor: root.accentColor
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "day " + root.doy()
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 9
                            font.weight: Font.Bold
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

            Repeater {
                model: [
                    { icon: root.cp(0xF0954), name: "day", v: root.progress(0) * 100 },
                    { icon: root.cp(0xF00ED), name: "week", v: root.progress(1) * 100 },
                    { icon: root.cp(0xF0150), name: "month", v: root.progress(2) * 100 },
                    { icon: root.cp(0xF0599), name: "year", v: root.progress(3) * 100 }
                ]

                delegate: Column {
                    id: prow
                    required property var modelData
                    required property int index

                    width: sysCol.width
                    spacing: 5

                    Item {
                        width: parent.width
                        height: 14

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            GlowText {
                                icon: true
                                anchors.verticalCenter: parent.verticalCenter
                                text: prow.modelData.icon
                                period: 3400
                                delay: prow.index * 300
                                glowColor: root.accentColor
                                color: root.accentColor
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: prow.modelData.name
                                color: root.accentColor
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(prow.modelData.v) + "%"
                            color: root.titleColor
                            font.family: root.mono
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
                            width: Math.max(6, parent.width * Math.min(100, prow.modelData.v) / 100)

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.accentColor }
                                GradientStop { position: 1.0; color: root.toneB }
                            }

                            layer.enabled: root.glowOn
                            layer.effect: MultiEffect {
                                autoPaddingEnabled: true
                                shadowEnabled: true
                                shadowColor: root.accentColor
                                shadowBlur: 1.0
                                shadowOpacity: 0.3 + 0.5 * root.todayPulse
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: stack
        width: 330
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        opacity: root.open
        transform: Translate { y: 24 * (1 - root.open) }

        Rectangle {
            id: formCard
            width: parent.width
            height: col.implicitHeight + 26
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: root.tint(root.edgeColor, 0.75)

            Frost {}

            GradBorder {
                rr: 12
                c1: root.edgeColor
                c2: root.edgeAlt
                c3: root.edgeColor
                c4: root.edgeAlt
                cycle: 9000
            }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 7





            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Item {
                    id: avatar
                    width: 52
                    height: 52

                    Glow {
                        visible: root.glowOn
                        width: 190
                        height: 190
                        anchors.centerIn: parent
                        tint: root.accentColor
                        strength: 0.35
                    }

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
                            border.color: index === 0 ? root.edgeColor : root.edgeAlt
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

                    Repeater {
                            model: userModel

                            delegate: Item {
                                readonly property bool hit: model.name === user.text

                                function sync() {
                                    if (hit) {
                                        root.faceHome = model.homeDir ? model.homeDir : ""
                                        root.faceIcon = model.icon ? model.icon : ""
                                    } else if (root.faceHome === model.homeDir) {
                                        root.faceHome = ""
                                        root.faceIcon = ""
                                    }
                                }

                                visible: false
                                onHitChanged: sync()
                                Component.onCompleted: sync()
                            }
                        }

                    Image {
                        id: faceMain
                        anchors.fill: parent
                        visible: false
                        source: root.faceHome.length > 0 ? "file://" + root.faceHome + "/.face" : ""
                        sourceSize.width: 208
                        sourceSize.height: 208
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        layer.enabled: true
                    }

                    Image {
                        id: faceAlt
                        anchors.fill: parent
                        visible: false
                        source: faceMain.status !== Image.Ready && root.faceIcon.length > 0 ? (root.faceIcon.indexOf("://") > 0 ? root.faceIcon : "file://" + root.faceIcon) : ""
                        sourceSize.width: 208
                        sourceSize.height: 208
                        fillMode: Image.PreserveAspectCrop
                        cache: false
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
                        source: faceMain.status === Image.Ready ? faceMain : faceAlt
                        visible: faceMain.status === Image.Ready || faceAlt.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: faceMain.status === Image.Ready || faceAlt.status === Image.Ready ? "transparent" : root.cardColor
                        border.width: 1.5
                        border.color: root.edgeColor

                        GlowText {
                            icon: true
                            anchors.centerIn: parent
                            period: 2600
                            visible: faceMain.status !== Image.Ready && faceAlt.status !== Image.Ready
                            text: root.cp(0xF0004)
                            color: root.accentColor
                            font.family: root.mono
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
                        text: root.greeting()
                        color: root.toneB
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    GlowText {
                        period: 2400
                        delay: 800
                        text: user.text.length > 0 ? user.text : "welcome"
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    GlowText {
                        period: 3000
                        delay: 600
                        glowColor: root.failed ? root.failColor : root.accentColor
                        text: root.busy ? "checking\u2026" : root.failed ? "wrong password" + (root.attempts > 1 ? "  \u00d7" + root.attempts : "") : "enter to login"
                        color: root.failed ? root.failColor : root.textColor
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

                DField {
                    id: user
                    width: parent.width
                    icon: "\uDB80\uDC04"
                    text: userModel.lastUser
                    placeholderText: "username"
                    Keys.onReturnPressed: pass.forceActiveFocus()
                    Keys.onEnterPressed: pass.forceActiveFocus()
                }

                DField {
                    id: pass
                    width: parent.width
                    icon: "\uDB80\uDF3E"
                    echoMode: root.reveal ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "\u25cf"
                    placeholderText: ""
                    color: root.reveal ? root.titleColor : "transparent"
                    bad: root.failed
                    focus: true
                    onTextChanged: root.failed = false
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()

                    property real shakeX: 0

                    transform: Translate { x: pass.shakeX }

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: pass; property: "shakeX"; to: -9; duration: 50 }
                        NumberAnimation { target: pass; property: "shakeX"; to: 9; duration: 70 }
                        NumberAnimation { target: pass; property: "shakeX"; to: -6; duration: 60 }
                        NumberAnimation { target: pass; property: "shakeX"; to: 6; duration: 60 }
                        NumberAnimation { target: pass; property: "shakeX"; to: 0; duration: 50 }
                    }

                    GlowText {
                        anchors.centerIn: parent
                        visible: pass.text.length === 0
                        glowColor: root.accentColor
                        period: 2400
                        text: "password"
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 11
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: !root.reveal

                        Repeater {
                            model: root.reveal ? 0 : Math.min(pass.text.length, 22)

                            delegate: Rectangle {
                                required property int index

                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.failed ? root.failColor : root.tonePalette[index % root.tonePalette.length]
                                scale: 0.3

                                Component.onCompleted: scale = 1

                                Behavior on scale {
                                    NumberAnimation { duration: 110; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }

                    GlowText {
                        icon: true
                        x: parent.width - width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.reveal ? "\uDB80\uDE08" : "\uDB80\uDE09"
                        period: 3000
                        blink: !eye.containsMouse
                        glowColor: root.accentColor
                        color: eye.containsMouse ? root.accentColor : root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 15

                        MouseArea {
                            id: eye
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.reveal = !root.reveal
                        }
                    }
                }

            Rectangle {
                id: loginBtn
                width: parent.width
                height: 32
                radius: 8
                color: root.tint(root.accentColor, lbArea.pressed ? 0.34 : lbArea.containsMouse ? 0.24 : 0.14)
                border.width: 1
                border.color: root.tint(root.edgeColor, lbArea.containsMouse ? 1 : 0.7)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                GlowText {
                    anchors.centerIn: parent
                    text: "login"
                    color: root.accentColor
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: lbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }

            GlowText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "enter to login  \u00b7  tab to switch"
                period: 4000
                delay: 1000
                glowColor: root.accentColor
                color: root.mutedColor
                font.family: root.mono
                font.pixelSize: 9
            }

                ComboBox {
                    id: session
                    width: parent.width
                    height: 28
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    font.family: root.mono
                    font.pixelSize: 11

                    contentItem: Text {
                        leftPadding: 12
                        rightPadding: 30
                        text: "Session  \u00b7  " + session.displayText
                        color: root.textColor
                        font: session.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: GlowText {
                        x: session.width - width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        icon: true
                        period: 3200
                        glowColor: root.accentColor
                        text: "\uDB80\uDD40"
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 14
                    }

                    background: Rectangle {
                        radius: 8
                        color: root.cardColor
                        border.width: 1
                        border.color: root.tint(root.edgeColor, session.hovered || session.popup.visible ? 0.7 : 0.3)

                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }

                    delegate: ItemDelegate {
                        id: sd
                        width: session.width - 2
                        height: 30
                        highlighted: session.highlightedIndex === index

                        contentItem: Text {
                            text: model.name
                            color: sd.highlighted ? root.accentColor : root.textColor
                            font: session.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: 6
                            color: sd.highlighted ? root.tint(root.accentColor, 0.16) : "transparent"
                        }
                    }

                    popup: Popup {
                        y: -implicitHeight - 4
                        width: session.width
                        implicitHeight: Math.min(contentItem.implicitHeight, 190) + 2
                        padding: 1

                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: session.popup.visible ? session.delegateModel : null
                            currentIndex: session.highlightedIndex
                        }

                        background: Rectangle {
                            radius: 8
                            color: root.panelColor
                            border.width: 1
                            border.color: root.tint(root.edgeColor, 0.75)
                        }
                    }
                }

            Row {
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
    }

    Row {
        id: powerRow
        anchors.horizontalCenter: stack.horizontalCenter
        anchors.top: stack.bottom
        anchors.topMargin: 14
        spacing: 10
        opacity: root.open

        Repeater {
            model: [
                { glyph: root.cp(0xF0594), act: 0 },
                { glyph: root.cp(0xF0425), act: 1 },
                { glyph: root.cp(0xF0709), act: 2 }
            ]

            delegate: Rectangle {
                id: pb
                required property var modelData

                width: 44
                height: 30
                radius: 9
                color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.5)
                border.width: 1
                border.color: root.tint(root.edgeAlt, pArea.containsMouse ? 0.9 : 0.45)
                scale: pArea.containsMouse ? 1.08 : 1

                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.tint(root.toneB, pArea.containsMouse ? 0.35 : 0.14)

                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                GlowText {
                    icon: true
                    anchors.centerIn: parent
                    text: pb.modelData.glyph
                    period: 3000
                    delay: pb.modelData.act * 500
                    glowColor: root.toneB
                    color: root.toneB
                    font.family: root.mono
                    font.pixelSize: 15
                }

                MouseArea {
                    id: pArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pb.modelData.act === 0)
                            sddm.suspend()
                        else if (pb.modelData.act === 1)
                            sddm.powerOff()
                        else
                            sddm.reboot()
                    }
                }
            }
        }
    }

    Timer {
        interval: root.wxReady ? 600000 : 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.wxRefresh()
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.busy = false
            root.attempts += 1
            pass.text = ""
            root.failed = true
            shake.restart()
            pass.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (user.text.length === 0 && userModel.count > 0) {
            var n = userModel.data(userModel.index(0, 0), Qt.UserRole + 1)
            if (n)
                user.text = n
        }
        openAnim.start()
        pass.forceActiveFocus()
    }
}
