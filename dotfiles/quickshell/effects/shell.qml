import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

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
    property bool themeReady: false
    property string current: "judgement"
    property real goldChance: 0.5
    property real cooldown: 4.0
    property real lastRun: 0
    property real nowSec: Date.now() / 1000

    property color themeBackground: "#282525"
    property color themeSurface: "#464036"
    property color themeSurfaceAlt: "#605642"
    property color themeForeground: "#E0DFE4"
    property color themeSubtext: "#BBB9B7"
    property color themeMuted: "#8D8981"
    property color themeAccent: "#8C753F"
    property color themeBlue: "#8A9AAB"
    property color themeGreen: "#9DBB7E"
    property color themeRed: "#CE8382"
    property color themeYellow: "#C6A86F"

    Behavior on themeBackground { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeSurface { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeSurfaceAlt { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeForeground { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeSubtext { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeMuted { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeAccent { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeBlue { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeGreen { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeRed { enabled: root.themeReady; ColorAnimation { duration: 400 } }
    Behavior on themeYellow { enabled: root.themeReady; ColorAnimation { duration: 400 } }

    property color basePanelColor: Qt.rgba(themeBackground.r, themeBackground.g, themeBackground.b, 0.96)
    property color baseCardColor: Qt.rgba(themeSurface.r, themeSurface.g, themeSurface.b, 0.92)
    property color baseTrackColor: Qt.rgba(themeSurfaceAlt.r, themeSurfaceAlt.g, themeSurfaceAlt.b, 0.80)
    property color lineColor: Qt.rgba(themeMuted.r, themeMuted.g, themeMuted.b, 0.30)

    property color titleColor: themeForeground
    property color textColor: themeSubtext
    property color mutedColor: themeMuted
    property color accentColor: themeAccent
    property color infoColor: themeBlue
    property color warningColor: themeYellow
    property color connectedColor: themeGreen
    property color dangerColor: themeRed

    property color stateColor: {
        if (current === "portal")
            return Qt.rgba(connectedColor.r + (warningColor.r - connectedColor.r) * goldChance,
                           connectedColor.g + (warningColor.g - connectedColor.g) * goldChance,
                           connectedColor.b + (warningColor.b - connectedColor.b) * goldChance, 1)
        if (current === "ice")
            return infoColor
        if (current === "glass")
            return dangerColor
        if (current === "blackhole")
            return warningColor
        return accentColor
    }
    Behavior on stateColor { ColorAnimation { duration: 250 } }

    property string fontName: "JetBrainsMono Nerd Font"

    readonly property var effects: [
        { key: "judgement", name: "Judgement Cut", tag: "Vergil", time: "~3.6s" },
        { key: "portal", name: "Portal", tag: "Evil Morty", time: "~3.3s" },
        { key: "ice", name: "Ice", tag: "Frozen", time: "~3.8s" },
        { key: "glass", name: "Glass Break", tag: "Shattered", time: "~3.0s" },
        { key: "blackhole", name: "Black Hole", tag: "Event horizon", time: "~3.5s" }
    ]

    readonly property var shortcuts: [
        { keys: ["SUPER", "SHIFT", "B"], what: "Run selected effect" },
        { keys: ["SUPER", "CTRL", "SHIFT", "B"], what: "Test run, no close" },
        { keys: ["SUPER", "ALT", "B"], what: "Open this picker" }
    ]

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function vivid(c, minS, minL, maxL) {
        var h = c.hslHue >= 0 ? c.hslHue : themeBlue.hslHue
        return Qt.hsla(h < 0 ? 0.62 : h,
                       Math.max(c.hslSaturation, minS),
                       Math.min(maxL, Math.max(c.hslLightness, minL)), 1)
    }
    readonly property color hotColor: vivid(themeForeground, 0.55, 0.80, 0.90)
    readonly property color glowColor: vivid(themeBlue, 0.60, 0.60, 0.72)
    readonly property color midColor: vivid(themeAccent, 0.75, 0.62, 0.70)
    readonly property color outerColor: vivid(themeAccent, 0.80, 0.45, 0.55)

    function currentInfo() {
        for (var i = 0; i < effects.length; i++)
            if (effects[i].key === current)
                return effects[i]
        return effects[0]
    }

    function parseColor(value, fallback) {
        var s = String(value || "").trim()
        if (!/^#[0-9a-fA-F]{6}$/.test(s))
            return fallback
        return Qt.rgba(parseInt(s.substring(1, 3), 16) / 255,
                       parseInt(s.substring(3, 5), 16) / 255,
                       parseInt(s.substring(5, 7), 16) / 255, 1)
    }

    function applyTheme(data) {
        var lines = String(data || "").split("\n")
        var colors = {}
        var inColors = false
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0 || line.charAt(0) === "#")
                continue
            if (line === "[colors]") { inColors = true; continue }
            if (line.charAt(0) === "[") { inColors = false; continue }
            var eq = line.indexOf("=")
            if (!inColors || eq < 0)
                continue
            colors[line.substring(0, eq).trim()] = line.substring(eq + 1).trim()
        }
        if (colors.background) themeBackground = parseColor(colors.background, themeBackground)
        if (colors.surface) themeSurface = parseColor(colors.surface, themeSurface)
        if (colors.surface_alt) themeSurfaceAlt = parseColor(colors.surface_alt, themeSurfaceAlt)
        if (colors.foreground) themeForeground = parseColor(colors.foreground, themeForeground)
        if (colors.subtext) themeSubtext = parseColor(colors.subtext, themeSubtext)
        if (colors.muted) themeMuted = parseColor(colors.muted, themeMuted)
        if (colors.accent) themeAccent = parseColor(colors.accent, themeAccent)
        if (colors.blue) themeBlue = parseColor(colors.blue, themeBlue)
        if (colors.green) themeGreen = parseColor(colors.green, themeGreen)
        if (colors.red) themeRed = parseColor(colors.red, themeRed)
        if (colors.yellow) themeYellow = parseColor(colors.yellow, themeYellow)
    }

    function setConf(key, value) {
        Quickshell.execDetached(["bash", "-c",
            "f=\"$HOME/.config/mycfg/blackhole.conf\"; mkdir -p \"$(dirname \"$f\")\"; touch \"$f\"; " +
            "if grep -qiE \"^[[:space:]]*$1[[:space:]]*=\" \"$f\"; then " +
            "sed -i -E \"s|^[[:space:]]*$1[[:space:]]*=.*|$1 = $2|I\" \"$f\"; " +
            "else printf '%s = %s\\n' \"$1\" \"$2\" >> \"$f\"; fi",
            "_", key, String(value)])
    }

    function cycle(step) {
        var idx = 0
        for (var i = 0; i < effects.length; i++)
            if (effects[i].key === current)
                idx = i
        idx = (idx + step + effects.length) % effects.length
        selectEffect(effects[idx].key)
    }

    function agoText() {
        if (lastRun <= 0)
            return "Never"
        var d = Math.max(0, nowSec - lastRun)
        if (d < 60) return Math.floor(d) + "s ago"
        if (d < 3600) return Math.floor(d / 60) + "m ago"
        if (d < 86400) return Math.floor(d / 3600) + "h ago"
        return Math.floor(d / 86400) + "d ago"
    }

    function cooldownLeft() {
        if (lastRun <= 0 || cooldown <= 0)
            return 0
        return Math.max(0, cooldown - (nowSec - lastRun))
    }

    function cooldownText(v) {
        return (Math.round(v * 2) / 2) + "s"
    }

    function selectEffect(key) {
        current = key
        setConf("effect", key)
        autoCloseTimer.restart()
    }

    function testEffect(key) {
        selectEffect(key)
        Quickshell.execDetached(["bash", "-c",
            "sleep 0.45; \"$HOME/.config/hypr/scripts/blackhole\" --dry"])
        closePopup()
    }

    function runEffect() {
        Quickshell.execDetached(["bash", "-c",
            "sleep 0.45; \"$HOME/.config/hypr/scripts/blackhole\""])
        closePopup()
    }

    function reloadTheme() {
        if (!themeProcess.running) themeProcess.running = true
    }

    function closePopup() {
        root.shown = false
        quitTimer.restart()
    }

    function refreshPopup() {
        reloadTheme()
        if (!confProcess.running) confProcess.running = true
        if (!lastRunProcess.running) lastRunProcess.running = true
        autoCloseTimer.restart()
    }

    component DesktopMock: Item {
        id: dm
        required property var th
        property real pull: 0
        property bool showWins: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(dm.th.themeAccent, 1.4) }
                GradientStop { position: 1.0; color: Qt.darker(dm.th.themeBlue, 2.6) }
            }
        }
        Rectangle {
            width: parent.width
            height: Math.max(4, parent.height * 0.07)
            color: Qt.rgba(dm.th.themeBackground.r, dm.th.themeBackground.g, dm.th.themeBackground.b, 0.92)
        }
        Repeater {
            model: [
                { x: 0.05, y: 0.14, w: 0.48, h: 0.46, k: 0 },
                { x: 0.38, y: 0.30, w: 0.52, h: 0.50, k: 1 },
                { x: 0.12, y: 0.56, w: 0.36, h: 0.34, k: 2 }
            ]
            Rectangle {
                id: win
                required property var modelData
                readonly property real s: 1 - 0.97 * Math.pow(dm.pull, 1.5)
                readonly property real pr: Math.pow(dm.pull, 2.2)
                readonly property color tone: modelData.k === 0 ? dm.th.themeBlue
                                              : (modelData.k === 1 ? dm.th.themeYellow : dm.th.themeGreen)
                width: Math.max(2, dm.width * modelData.w * s)
                height: Math.max(2, dm.height * modelData.h * s)
                x: dm.width * ((modelData.x + modelData.w / 2) * (1 - pr) + 0.5 * pr) - width / 2
                y: dm.height * ((modelData.y + modelData.h / 2) * (1 - pr) + 0.5 * pr) - height / 2
                rotation: 140 * pr
                radius: 3
                visible: dm.showWins && s > 0.05
                color: Qt.rgba(dm.th.themeBackground.r, dm.th.themeBackground.g, dm.th.themeBackground.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.8)

                Rectangle {
                    width: parent.width
                    height: parent.height * 0.16
                    radius: 3
                    color: Qt.rgba(win.tone.r, win.tone.g, win.tone.b, 0.85)
                }
                Column {
                    x: parent.width * 0.08
                    y: parent.height * 0.28
                    spacing: Math.max(2, parent.height * 0.08)
                    Rectangle { width: win.width * 0.70; height: Math.max(1, win.height * 0.05); radius: 1; color: Qt.rgba(1, 1, 1, 0.45) }
                    Rectangle { width: win.width * 0.52; height: Math.max(1, win.height * 0.05); radius: 1; color: Qt.rgba(1, 1, 1, 0.28) }
                    Rectangle { width: win.width * 0.62; height: Math.max(1, win.height * 0.05); radius: 1; color: Qt.rgba(1, 1, 1, 0.28) }
                }
            }
        }
    }

    component EffectPreview: Item {
        id: pv
        required property var th
        required property string fx
        required property var snapSrc
        required property var bgSrc
        property bool live: true

        property real grow: 0
        property real shatter: 0
        property real holeOpen: 0
        property real collapse: 0
        property real pop: 0
        property real reveal: 0
        property real clock: 0
        property real pull: 0
        property real suck: 0
        property real goldNow: 0

        readonly property bool shaderOk: fxLayer.status !== ShaderEffect.Error
        readonly property int growMs: fx === "judgement" ? 1700 : (fx === "glass" || fx === "blackhole" ? 550 : 1400)
        readonly property int holdMs: fx === "judgement" ? 140 : (fx === "ice" ? 180 : 0)
        readonly property int shatterMs: fx === "judgement" ? 1800 : (fx === "portal" ? 1900 : (fx === "ice" ? 2200 : (fx === "blackhole" ? 1000 : 2400)))

        clip: true

        DesktopMock {
            anchors.fill: parent
            th: pv.th
            pull: pv.pull
        }

        ShaderEffect {
            id: fxLayer
            anchors.fill: parent
            visible: pv.grow > 0.001 && status !== ShaderEffect.Error

            property real time: pv.clock
            property real grow: pv.grow
            property real breakAmt: pv.shatter
            property real openAmt: pv.holeOpen
            property real collapse: pv.collapse
            property real pop: pv.pop
            property real reveal: pv.reveal
            property real snapAmt: 1
            property real goldMix: pv.goldNow
            property real suck: pv.suck
            property real useShot: pv.fx === "blackhole" ? 1 : 0
            property variant screenTex: pv.snapSrc
            property variant backTex: pv.bgSrc
            property variant snap: pv.snapSrc
            property size resolution: Qt.size(width, height)
            property color hotColor: pv.th.hotColor
            property color glowColor: pv.th.glowColor
            property color bgColor: pv.th.themeBackground

            fragmentShader: Qt.resolvedUrl("../blackhole/screenfx." + pv.fx + ".frag.qsb")

            onStatusChanged: {
                if (status === ShaderEffect.Error)
                    console.warn("[effects] preview shader failed:", fragmentShader, "\n" + log)
            }
        }

        ShaderEffect {
            id: lensLayer
            anchors.centerIn: parent
            width: Math.min(pv.width, pv.height) * 1.8
            height: width
            visible: pv.fx === "blackhole" && pv.holeOpen > 0.001 && pv.pop < 0.999 && status !== ShaderEffect.Error
            opacity: Math.min(1, pv.holeOpen * 2.2) * Math.max(0, 1 - pv.pop * 6)
            scale: (0.03 + 0.97 * pv.holeOpen) * (1 - 0.9 * Math.pow(pv.collapse, 1.8))
            rotation: -6 - 8 * (1 - pv.holeOpen) - 12 * pv.collapse

            property real time: pv.clock
            property real grow: pv.holeOpen
            property real collapse: pv.collapse
            property color hotColor: pv.th.hotColor
            property color midColor: pv.th.midColor
            property color outerColor: pv.th.outerColor
            property color glowColor: pv.th.glowColor

            fragmentShader: Qt.resolvedUrl("../blackhole/blackhole.disk.frag.qsb")
        }

        Item {
            anchors.fill: parent
            visible: !pv.shaderOk && pv.grow > 0.001

            Rectangle {
                anchors.fill: parent
                color: pv.fx === "ice" ? Qt.rgba(0.7, 0.9, 1, 0.32 * pv.grow * (1 - pv.shatter))
                       : Qt.rgba(1, 1, 1, 0.07 * pv.grow * (1 - pv.shatter))
            }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: Math.sqrt(pv.width * pv.width + pv.height * pv.height) * pv.grow
                    height: pv.fx === "judgement" ? 2 : 1.2
                    rotation: index * 25.7 + (pv.fx === "judgement" ? 12 : 0)
                    color: pv.fx === "judgement" && index % 2 ? Qt.rgba(1, 0.35, 0.8, 1) : pv.th.hotColor
                    opacity: Math.max(0, 1 - pv.shatter * 0.85)
                }
            }
            Rectangle {
                anchors.centerIn: parent
                visible: pv.holeOpen > 0.01 && pv.pop < 0.99
                width: Math.min(pv.width, pv.height) * 0.85 * pv.holeOpen * (1 - 0.9 * pv.collapse * pv.collapse)
                height: width
                radius: width / 2
                color: "black"
                opacity: 1 - pv.pop
                border.width: 2
                border.color: pv.fx === "portal" ? (pv.goldNow > 0.5 ? "#ffcc33" : "#33ff88") : pv.th.glowColor
            }
        }

        FrameAnimation {
            running: pv.live && pv.grow > 0
            onTriggered: pv.clock += frameTime * (1 + 5 * pv.collapse * pv.collapse)
        }

        SequentialAnimation {
            running: pv.live
            loops: Animation.Infinite

            ScriptAction {
                script: {
                    pv.grow = 0; pv.shatter = 0; pv.holeOpen = 0
                    pv.collapse = 0; pv.pop = 0; pv.reveal = 0
                    pv.pull = 0; pv.suck = 0; pv.clock = 0
                    pv.goldNow = Math.random() < pv.th.goldChance ? 1 : 0
                }
            }
            PauseAnimation { duration: 700 }
            NumberAnimation {
                target: pv; property: "grow"; to: 1
                duration: pv.growMs
                easing.type: pv.fx === "glass" ? Easing.OutCubic : Easing.Linear
            }
            PauseAnimation { duration: pv.holdMs }
            ParallelAnimation {
                NumberAnimation { target: pv; property: "shatter"; to: 1; duration: pv.shatterMs }
                SequentialAnimation {
                    PauseAnimation { duration: pv.fx === "blackhole" ? 560 : 380 }
                    NumberAnimation { target: pv; property: "holeOpen"; to: 1; duration: 700; easing.type: Easing.OutCubic }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 120 }
                    NumberAnimation { target: pv; property: "suck"; to: 1; duration: 1700; easing.type: Easing.InQuad }
                }
                SequentialAnimation {
                    PauseAnimation { duration: 600 }
                    NumberAnimation { target: pv; property: "pull"; to: 1; duration: 1100; easing.type: Easing.InQuad }
                }
            }
            PauseAnimation { duration: 250 }
            NumberAnimation { target: pv; property: "collapse"; to: 1; duration: 750; easing.type: Easing.InQuad }
            ParallelAnimation {
                NumberAnimation { target: pv; property: "pop"; to: 1; duration: 700; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: 250 }
                    NumberAnimation { target: pv; property: "reveal"; to: 1; duration: 1800 }
                }
            }
            PauseAnimation { duration: 700 }
        }
    }

    component ValueSlider: Item {
        id: sl
        required property var th
        property string label: ""
        property string valueText: ""
        property real frac: 0
        property color fill: th.accentColor
        readonly property bool dragging: slMouse.pressed
        signal moved(real f)
        signal released()

        width: parent ? parent.width : 300
        height: 28

        Text {
            id: slLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 76
            text: sl.label
            color: sl.th.mutedColor
            font.family: sl.th.fontName
            font.pixelSize: 8
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.left: slLabel.right
            anchors.right: slValue.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: sl.th.trackColor
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, sl.frac))
                height: parent.height
                radius: 4
                color: sl.fill
                Behavior on width { enabled: !slMouse.pressed; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: slMouse
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) { sl.moved(Math.max(0, Math.min(1, mouse.x / width))) }
                onPositionChanged: function(mouse) { if (pressed) sl.moved(Math.max(0, Math.min(1, mouse.x / width))) }
                onReleased: sl.released()
            }
        }
        Text {
            id: slValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            horizontalAlignment: Text.AlignRight
            text: sl.valueText
            color: sl.fill
            font.family: sl.th.fontName
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    IpcHandler {
        target: "effects"

        function toggle(): void {
            if (root.shown) { root.closePopup(); return }
            root.shown = true
            root.refreshPopup()
        }
        function show(): void { root.shown = true; root.refreshPopup() }
        function hide(): void { root.closePopup() }
    }

    Process {
        id: themeProcess
        running: true
        command: ["bash", "-c",
                  "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/theme/theme.conf\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyTheme(this.text)
                root.themeReady = true
            }
        }
    }

    Process {
        id: confProcess
        running: true
        command: ["bash", "-c",
                  "grep -i -E '^[[:space:]]*(effect|gold|cooldown)[[:space:]]*=' \"$HOME/.config/mycfg/blackhole.conf\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text || "").split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("=")
                    if (p.length < 2) continue
                    var k = p[0].trim().toLowerCase()
                    var v = p[1].trim().toLowerCase()
                    if (k === "effect" && (v === "glass" || v === "ice" || v === "portal" || v === "judgement" || v === "blackhole"))
                        root.current = v
                    if (k === "cooldown") {
                        var c = parseFloat(v)
                        if (!isNaN(c))
                            root.cooldown = Math.max(0, Math.min(10, c))
                    }
                    if (k === "gold") {
                        var n = parseFloat(v)
                        if (!isNaN(n))
                            root.goldChance = Math.max(0, Math.min(1, v.indexOf("%") >= 0 ? n / 100 : n))
                    }
                }
            }
        }
    }

    Process {
        id: lastRunProcess
        running: true
        command: ["bash", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/doiz-blackhole.last\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseFloat(String(this.text || "").trim())
                root.lastRun = isNaN(n) ? 0 : n
            }
        }
    }

    Timer {
        id: autoCloseTimer
        interval: 6000
        running: true
        onTriggered: {
            if (panelHover.hovered || goldSlider.dragging || coolSlider.dragging)
                autoCloseTimer.restart()
            else
                root.closePopup()
        }
    }
    Timer {
        id: themeRefreshTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.reloadTheme()
    }
    Timer {
        id: liveTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.nowSec = Date.now() / 1000
            if (!lastRunProcess.running) lastRunProcess.running = true
        }
    }
    Timer { id: quitTimer; interval: 120; onTriggered: Qt.quit() }

    PanelWindow {
        id: clickLayer
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "doiz-effects-click-layer"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; onClicked: root.closePopup() }
    }

    PanelWindow {
        id: effectsPanel
        visible: root.shown
        anchors { top: true; right: true }
        margins { top: 42; right: 8 }
        implicitWidth: 340
        implicitHeight: contentColumn.implicitHeight + 24
        color: "transparent"
        WlrLayershell.namespace: "doiz-effects-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        DesktopMock {
            id: snapMock
            th: root
            width: 340
            height: 191
        }
        ShaderEffectSource {
            id: snapSource
            visible: false
            width: 340
            height: 191
            sourceItem: snapMock
            hideSource: true
            live: true
        }
        DesktopMock {
            id: bgMock
            th: root
            showWins: false
            width: 340
            height: 191
        }
        ShaderEffectSource {
            id: bgSource
            visible: false
            width: 340
            height: 191
            sourceItem: bgMock
            hideSource: true
            live: true
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            color: root.panelColor
            radius: 8
            border.width: 1
            border.color: root.tint(root.stateColor, 0.35)
            Behavior on border.color { ColorAnimation { duration: 250 } }

            NumberAnimation on opacity { from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }

            HoverHandler { id: panelHover }

            MouseArea {
                anchors.fill: parent
                onWheel: function(wheel) { root.cycle(wheel.angleDelta.y > 0 ? -1 : 1) }
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
                        id: iconTile
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40; radius: 6
                        color: root.tint(root.stateColor, 0.16)
                        Behavior on color { ColorAnimation { duration: 250 } }
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "󰅖"
                            color: root.stateColor
                            font.family: root.fontName
                            font.pixelSize: 21
                        }
                    }

                    Column {
                        anchors.left: iconTile.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 180
                        spacing: 2
                        Text {
                            width: parent.width
                            text: "CLOSE EFFECT"
                            color: root.titleColor
                            font.family: root.fontName
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.currentInfo().name
                            color: root.stateColor
                            font.family: root.fontName
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 54; height: 40; radius: 6
                        color: root.cardColor
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.currentInfo().time
                            color: root.stateColor
                            font.family: root.fontName
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.lineColor }

                Row {
                    width: parent.width
                    height: 20
                    spacing: 8
                    Text {
                        width: 18
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "󰐊"
                        color: root.infoColor
                        font.family: root.fontName
                        font.pixelSize: 14
                    }
                    Text {
                        width: parent.width - 26
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "EFFECT PREVIEW"
                        color: root.mutedColor
                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }

                Grid {
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: root.effects

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool active: root.current === modelData.key
                            readonly property real pw: width - 8

                            width: (contentColumn.width - 6) / 2
                            height: 4 + Math.round(pw * 9 / 16) + 5 + 28 + 4
                            radius: 6
                            color: hover.hovered ? root.tint(root.accentColor, 0.12) : root.cardColor
                            border.width: active ? 1 : 0
                            border.color: root.connectedColor
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: hover; onHoveredChanged: autoCloseTimer.restart() }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectEffect(card.modelData.key)
                            }

                            EffectPreview {
                                id: preview
                                x: 4
                                y: 4
                                width: card.pw
                                height: Math.round(card.pw * 9 / 16)
                                th: root
                                fx: card.modelData.key
                                snapSrc: snapSource
                                bgSrc: bgSource
                                live: root.shown
                            }

                            Rectangle {
                                x: preview.x
                                y: preview.y
                                width: preview.width
                                height: preview.height
                                color: "transparent"
                                radius: 2
                                border.width: 1
                                border.color: root.lineColor
                            }

                            Rectangle {
                                visible: hover.hovered
                                x: preview.x + preview.width - width - 4
                                y: preview.y + preview.height - height - 4
                                width: 24; height: 24; radius: 6
                                color: playMouse.containsMouse ? root.tint(root.accentColor, 0.30) : root.panelColor
                                border.width: 1
                                border.color: root.lineColor
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "󰐊"
                                    color: root.accentColor
                                    font.family: root.fontName
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: playMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.testEffect(card.modelData.key)
                                }
                            }

                            Item {
                                x: 8
                                y: preview.y + preview.height + 5
                                width: card.width - 16
                                height: 28

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: checkMark.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: card.modelData.name
                                        color: root.titleColor
                                        font.family: root.fontName
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: card.modelData.tag + "  ·  " + card.modelData.time
                                        color: root.mutedColor
                                        font.family: root.fontName
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    id: checkMark
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    horizontalAlignment: Text.AlignHCenter
                                    text: card.active ? "󰄬" : ""
                                    color: root.connectedColor
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.lineColor }

                Row {
                    id: controlRow
                    width: parent.width
                    height: 44
                    spacing: 6

                    Rectangle {
                        width: (controlRow.width - 18) / 4
                        height: 44
                        radius: 6
                        color: prevMouse.containsMouse ? root.tint(root.accentColor, 0.18) : root.cardColor
                        border.width: 1
                        border.color: root.lineColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "󰒮"
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 19
                        }
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycle(-1)
                        }
                    }

                    Rectangle {
                        width: (controlRow.width - 18) / 4
                        height: 44
                        radius: 6
                        color: testMouse.containsMouse ? root.tint(root.stateColor, 0.22) : root.tint(root.stateColor, 0.10)
                        border.width: 1
                        border.color: root.tint(root.stateColor, 0.55)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰐊"
                                color: root.stateColor
                                font.family: root.fontName
                                font.pixelSize: 17
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TEST"
                                color: root.stateColor
                                font.family: root.fontName
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            id: testMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.testEffect(root.current)
                        }
                    }

                    Rectangle {
                        width: (controlRow.width - 18) / 4
                        height: 44
                        radius: 6
                        color: runMouse.containsMouse ? root.tint(root.dangerColor, 0.20) : root.cardColor
                        border.width: 1
                        border.color: runMouse.containsMouse ? root.dangerColor : root.lineColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰐥"
                                color: root.dangerColor
                                font.family: root.fontName
                                font.pixelSize: 17
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "RUN"
                                color: root.dangerColor
                                font.family: root.fontName
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            id: runMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runEffect()
                        }
                    }

                    Rectangle {
                        width: (controlRow.width - 18) / 4
                        height: 44
                        radius: 6
                        color: nextMouse.containsMouse ? root.tint(root.accentColor, 0.18) : root.cardColor
                        border.width: 1
                        border.color: root.lineColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "󰒭"
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 19
                        }
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycle(1)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: root.current === "portal" ? 28 : 0
                    visible: height > 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    ValueSlider {
                        id: goldSlider
                        th: root
                        width: parent.width
                        label: "GOLD PORTAL"
                        fill: root.warningColor
                        frac: root.goldChance
                        valueText: Math.round(root.goldChance * 100) + "%"
                        onMoved: function(f) {
                            root.goldChance = Math.round(f * 20) / 20
                            autoCloseTimer.restart()
                        }
                        onReleased: root.setConf("gold", Math.round(root.goldChance * 100) + "%")
                    }
                }

                ValueSlider {
                    id: coolSlider
                    th: root
                    width: parent.width
                    label: "COOLDOWN"
                    fill: root.stateColor
                    frac: root.cooldown / 10
                    valueText: root.cooldownText(root.cooldown)
                    onMoved: function(f) {
                        root.cooldown = Math.round(f * 20) / 2
                        autoCloseTimer.restart()
                    }
                    onReleased: root.setConf("cooldown", root.cooldown)
                }

                Row {
                    id: infoRow
                    width: parent.width
                    height: 44
                    spacing: 6

                    Rectangle {
                        width: (infoRow.width - 6) / 2
                        height: 44
                        radius: 6
                        color: root.cardColor
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 3
                            Text {
                                text: "LAST RUN"
                                color: root.mutedColor
                                font.family: root.fontName
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: root.agoText()
                                color: root.textColor
                                font.family: root.fontName
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: (infoRow.width - 6) / 2
                        height: 44
                        radius: 6
                        color: root.cardColor
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 3
                            Text {
                                text: "STATUS"
                                color: root.mutedColor
                                font.family: root.fontName
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: root.cooldownLeft() > 0 ? "Cooldown " + Math.ceil(root.cooldownLeft()) + "s" : "Ready"
                                color: root.cooldownLeft() > 0 ? root.warningColor : root.connectedColor
                                font.family: root.fontName
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.lineColor }

                Row {
                    width: parent.width
                    height: 20
                    spacing: 8
                    Text {
                        width: 18
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "󰋼"
                        color: root.infoColor
                        font.family: root.fontName
                        font.pixelSize: 14
                    }
                    Text {
                        width: parent.width - 26
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "SHORTCUTS"
                        color: root.mutedColor
                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: root.shortcuts

                        delegate: Rectangle {
                            id: keyRow
                            required property var modelData
                            width: contentColumn.width
                            height: 32
                            radius: 6
                            color: root.cardColor

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: keyRow.modelData.what
                                color: root.textColor
                                font.family: root.fontName
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Repeater {
                                    model: keyRow.modelData.keys

                                    delegate: Rectangle {
                                        id: cap
                                        required property string modelData
                                        width: capText.implicitWidth + 10
                                        height: 18
                                        radius: 4
                                        color: root.trackColor
                                        border.width: 1
                                        border.color: root.lineColor
                                        Text {
                                            id: capText
                                            anchors.centerIn: parent
                                            text: cap.modelData
                                            color: root.titleColor
                                            font.family: root.fontName
                                            font.pixelSize: 8
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
