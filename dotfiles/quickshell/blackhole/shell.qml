import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root

    property string targetScreen: ""
    property real holeScale: 1.8
    property string effect: "judgement"
    property real goldChance: 0.5
    property real goldNow: 0
    readonly property bool portalFx: effect === "portal"
    readonly property bool cutFx: effect === "judgement"
    readonly property bool ownFx: portalFx || cutFx
    readonly property bool iceFx: effect === "ice"
    readonly property bool diskFx: effect === "blackhole"
    property real suck: 0
    readonly property string shotPath: Quickshell.env("DOIZ_BH_SHOT") || ""
    readonly property bool shotMode: diskFx && shotPath !== ""
    readonly property var wins: {
        try {
            var w = JSON.parse(Quickshell.env("DOIZ_BH_WINS") || "[]")
            return Array.isArray(w) ? w : []
        } catch (e) {
            return []
        }
    }

    property real grow: 0
    property real shatter: 0
    property real holeOpen: 0
    property real collapse: 0
    property real pop: 0
    property real reveal: 0
    property real clock: 0

    property bool snapWanted: false
    property bool animStarted: false
    property bool closeQueued: false
    property real snapAmt: 0
    readonly property int shatterMs: diskFx ? 1000 : snapAmt > 0.5 ? (cutFx ? 1800 : (portalFx ? 1900 : (iceFx ? 2200 : 2400))) : (cutFx ? 800 : (portalFx ? 1400 : 700))

    property color themeBackground: "#1b1b1b"
    property color themeForeground: "#e0e0e0"
    property color themeAccent: "#4a4a4a"
    property color themeAccentAlt: "#8a8a8a"
    property color themeBlue: "#9a9a9a"

    function vivid(c, minS, minL, maxL) {
        var h = c.hslHue >= 0 ? c.hslHue : themeAccentAlt.hslHue
        return Qt.hsla(h < 0 ? 0.62 : h,
                       Math.max(c.hslSaturation, minS),
                       Math.min(maxL, Math.max(c.hslLightness, minL)), 1)
    }

    readonly property color hotColor: vivid(themeForeground, 0.55, 0.80, 0.90)
    readonly property color midColor: vivid(themeAccentAlt, 0.75, 0.62, 0.70)
    readonly property color outerColor: vivid(themeAccent, 0.80, 0.45, 0.55)
    readonly property color glowColor: vivid(themeBlue, 0.60, 0.60, 0.72)

    function applyTheme(text) {
        var lines = String(text || "").split("\n")
        var inColors = false
        var map = {}
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.length === 0 || line.charAt(0) === "#" || line.charAt(0) === ";")
                continue
            if (line.charAt(0) === "[") {
                inColors = line === "[colors]"
                continue
            }
            var eq = line.indexOf("=")
            if (!inColors || eq < 0)
                continue
            var value = line.substring(eq + 1).trim()
            if (/^#[0-9a-fA-F]{6}$/.test(value))
                map[line.substring(0, eq).trim().toLowerCase()] = value
        }
        if (map.background) themeBackground = map.background
        if (map.foreground) themeForeground = map.foreground
        if (map.accent) themeAccent = map.accent
        if (map.accent_alt) themeAccentAlt = map.accent_alt
        if (map.blue) themeBlue = map.blue
    }

    Process {
        running: true
        command: ["bash", "-c",
                  "cat \"${XDG_CONFIG_HOME:-$HOME/.config}/theme/theme.conf\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.applyTheme(this.text)
        }
    }

    Process {
        running: true
        command: ["bash", "-c",
                  "grep -i -m1 -E '^[[:space:]]*effect[[:space:]]*=' \"$HOME/.config/mycfg/blackhole.conf\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = String(this.text || "").split("=")[1]
                v = v ? v.trim().toLowerCase() : ""
                if (v === "glass" || v === "ice" || v === "portal" || v === "judgement" || v === "blackhole")
                    root.effect = v
            }
        }
    }

    Process {
        running: true
        command: ["bash", "-c",
                  "grep -i -m1 -E '^[[:space:]]*gold[[:space:]]*=' \"$HOME/.config/mycfg/blackhole.conf\" 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = String(this.text || "").split("=")[1]
                v = v ? v.trim() : ""
                var pct = v.indexOf("%") >= 0
                var n = parseFloat(v)
                if (!isNaN(n))
                    root.goldChance = Math.max(0, Math.min(1, pct ? n / 100 : n))
            }
        }
    }

    function beginOpen(withSnap) {
        if (animStarted)
            return
        animStarted = true
        goldNow = Math.random() < goldChance ? 1 : 0
        snapTimeout.stop()
        snapAmt = withSnap ? 1 : 0
        if (!withSnap)
            snapWanted = false
        openAnim.restart()
    }

    Timer {
        id: snapTimeout

        interval: 450
        onTriggered: root.beginOpen(false)
    }

    IpcHandler {
        target: "blackhole"

        function open(screen: string): void {
            closeAnim.stop()
            openAnim.stop()
            snapTimeout.stop()
            root.grow = 0
            root.shatter = 0
            root.holeOpen = 0
            root.collapse = 0
            root.pop = 0
            root.reveal = 0
            root.snapAmt = 0
            root.suck = 0
            root.animStarted = false
            root.closeQueued = false
            root.snapWanted = false
            root.targetScreen = screen
            if (root.diskFx) {
                root.beginOpen(false)
                return
            }
            root.snapWanted = true
            snapTimeout.restart()
        }

        function close(): void {
            if (openAnim.running) {
                root.closeQueued = true
                return
            }
            closeAnim.restart()
        }
    }

    SequentialAnimation {
        id: openAnim

        onFinished: {
            if (root.closeQueued) {
                root.closeQueued = false
                closeAnim.restart()
            }
        }

        NumberAnimation {
            target: root
            property: "grow"
            to: 1
            duration: root.cutFx ? 1700 : (root.portalFx ? 1400 : (root.iceFx ? 1400 : 550))
            easing.type: (root.iceFx || root.portalFx || root.cutFx) ? Easing.Linear : Easing.OutCubic
        }
        PauseAnimation { duration: root.snapAmt > 0.5 ? (root.cutFx ? 140 : (root.iceFx ? 180 : 0)) : 0 }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "shatter"
                to: 1
                duration: root.shatterMs
                easing.type: Easing.Linear
            }
            SequentialAnimation {
                PauseAnimation { duration: root.diskFx ? 560 : 380 }
                NumberAnimation {
                    target: root
                    property: "holeOpen"
                    to: 1
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: root.diskFx ? 120 : 0 }
                NumberAnimation {
                    target: root
                    property: "suck"
                    to: 1
                    duration: root.diskFx ? 1700 : 0
                    easing.type: Easing.InQuad
                }
            }
        }
    }

    SequentialAnimation {
        id: closeAnim

        NumberAnimation {
            target: root
            property: "collapse"
            to: 1
            duration: 750
            easing.type: Easing.InQuad
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "pop"
                to: 1
                duration: 700
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation {
                    target: root
                    property: "reveal"
                    to: 1
                    duration: 1800
                    easing.type: Easing.Linear
                }
            }
        }
        onFinished: Qt.quit()
    }

    FrameAnimation {
        running: root.grow > 0
        onTriggered: root.clock += frameTime * (1 + 5 * root.collapse * root.collapse)
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool isTarget:
                root.targetScreen === ""
                    ? modelData === Quickshell.screens[0]
                    : modelData.name === root.targetScreen

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            color: "transparent"

            WlrLayershell.namespace: "doiz-blackhole"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Loader {
                id: snapLoader

                active: win.isTarget && root.snapWanted

                sourceComponent: ScreencopyView {
                    width: win.width
                    height: win.height
                    captureSource: win.screen
                    live: false
                    paintCursor: false
                    onHasContentChanged: {
                        if (hasContent)
                            root.beginOpen(true)
                    }
                }
            }

            ShaderEffectSource {
                id: snapSource

                visible: false
                width: win.width
                height: win.height
                sourceItem: snapLoader.item
                hideSource: true
                live: true
            }

            Image {
                id: shotImg

                visible: false
                source: win.isTarget && root.shotMode ? "file://" + root.shotPath : ""
                asynchronous: false
                cache: false
            }

            readonly property real shotK: shotImg.sourceSize.width > 0
                                          ? shotImg.sourceSize.width / Math.max(1, width) : 1

            Item {
                id: bgScene

                z: -1
                anchors.fill: parent
                visible: root.shotMode && win.isTarget && root.grow > 0.001 && root.reveal < 0.02
                layer.enabled: true
                layer.textureSize: shotImg.sourceSize

                Image {
                    anchors.fill: parent
                    source: shotImg.source
                    cache: true
                    smooth: true
                    fillMode: Image.Stretch
                }

                Repeater {
                    model: win.isTarget && root.shotMode ? root.wins : []

                    delegate: Image {
                        required property var modelData

                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h
                        source: shotImg.source
                        cache: true
                        smooth: true
                        fillMode: Image.Stretch
                        sourceClipRect: modelData.x > 10
                            ? Qt.rect((modelData.x - 6) * win.shotK, modelData.y * win.shotK,
                                      3 * win.shotK, modelData.h * win.shotK)
                            : Qt.rect((modelData.x + modelData.w + 3) * win.shotK, modelData.y * win.shotK,
                                      3 * win.shotK, modelData.h * win.shotK)
                    }
                }
            }

            ShaderEffect {
                id: screenFx

                anchors.fill: parent
                z: 0
                visible: win.isTarget && root.grow > 0.001 && status !== ShaderEffect.Error
                         && (!root.shotMode || shotImg.status === Image.Ready)

                property real time: root.clock
                property real grow: root.grow
                property real breakAmt: root.shatter
                property real openAmt: root.holeOpen
                property real collapse: root.collapse
                property real pop: root.pop
                property real reveal: root.reveal
                property real snapAmt: root.snapAmt
                property real goldMix: root.goldNow
                property real suck: root.suck
                property real useShot: (root.shotMode && shotImg.status === Image.Ready) ? 1 : 0
                property variant screenTex: shotImg
                property variant backTex: bgScene
                property variant snap: snapSource
                property size resolution: Qt.size(width, height)
                property color hotColor: root.hotColor
                property color glowColor: root.glowColor
                property color bgColor: root.themeBackground

                fragmentShader: Qt.resolvedUrl(root.cutFx ? "screenfx.judgement.frag.qsb"
                                               : (root.portalFx ? "screenfx.portal.frag.qsb"
                                                  : (root.iceFx ? "screenfx.ice.frag.qsb"
                                                                : (root.diskFx ? "screenfx.blackhole.frag.qsb" : "screenfx.glass.frag.qsb"))))
            }

            Rectangle {
                anchors.fill: parent
                visible: win.isTarget && root.grow > 0.001 && screenFx.status === ShaderEffect.Error
                color: Qt.rgba(root.themeBackground.r, root.themeBackground.g,
                               root.themeBackground.b, 0.30 * root.grow * (1 - root.reveal))
            }

            Item {
                id: hole

                z: 2
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * root.holeScale
                height: width
                visible: win.isTarget && root.holeOpen > 0.001 && root.pop < 0.999 && root.snapAmt < 0.5 && !root.ownFx
                opacity: Math.min(1, root.holeOpen * 2.2) * Math.max(0, 1 - root.pop * 6)
                scale: (0.03 + 0.97 * root.holeOpen) * (1 - 0.9 * Math.pow(root.collapse, 1.8))
                rotation: root.diskFx ? (-6 - 8 * (1 - root.holeOpen) - 12 * root.collapse)
                                    : (-3 - 25 * (1 - root.holeOpen) - 150 * root.collapse * root.collapse)

                ShaderEffect {
                    id: lens

                    anchors.fill: parent
                    visible: status !== ShaderEffect.Error

                    property real time: root.clock
                    property real grow: root.holeOpen
                    property real collapse: root.collapse
                    property color hotColor: root.hotColor
                    property color midColor: root.midColor
                    property color outerColor: root.outerColor
                    property color glowColor: root.glowColor

                    fragmentShader: Qt.resolvedUrl(root.diskFx ? "blackhole.disk.frag.qsb" : "blackhole.frag.qsb")
                }

                Canvas {
                    id: canvas

                    anchors.fill: parent
                    visible: lens.status === ShaderEffect.Error
                    renderTarget: Canvas.FramebufferObject

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()

                        var cx = width / 2
                        var cy = height / 2
                        var R = width * 0.11
                        var n = 14
                        var i, a, r

                        ctx.lineWidth = Math.max(1.5, width / 700)
                        ctx.strokeStyle = Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.85)
                        for (i = 0; i < 22; i++) {
                            a = i / 22 * Math.PI * 2 + Math.sin(i * 12.9898) * 0.12
                            r = width * (0.22 + 0.28 * Math.abs(Math.sin(i * 78.233)))
                            ctx.beginPath()
                            ctx.moveTo(cx + Math.cos(a) * R, cy + Math.sin(a) * R)
                            ctx.lineTo(cx + Math.cos(a + 0.03) * r * 0.55, cy + Math.sin(a + 0.03) * r * 0.55)
                            ctx.lineTo(cx + Math.cos(a - 0.02) * r, cy + Math.sin(a - 0.02) * r)
                            ctx.stroke()
                        }

                        ctx.beginPath()
                        for (i = 0; i < n; i++) {
                            a = i / n * Math.PI * 2
                            r = R * (0.5 + 0.95 * Math.pow(Math.abs(Math.sin(i * 12.9898)), 2))
                            if (i === 0) ctx.moveTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                            else ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                        }
                        ctx.closePath()
                        ctx.fillStyle = "#000000"
                        ctx.fill()
                        ctx.lineWidth = Math.max(2, R * 0.05)
                        ctx.strokeStyle = Qt.rgba(root.hotColor.r, root.hotColor.g, root.hotColor.b, 0.95)
                        ctx.stroke()
                    }
                }
            }
        }
    }
}
