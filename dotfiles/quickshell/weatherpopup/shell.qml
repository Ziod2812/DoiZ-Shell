import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string mono: "JetBrainsMono Nerd Font"

    property bool closing: false

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
    property color warmColor: "#aa978b"
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
        root.warmColor = pick("yellow", "#AA978B")
    }

    Process {
        command: ["sh", "-c", "cat \"$1/theme/theme.conf\" 2>/dev/null", "doiz", root.cfgHome]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    readonly property real colW: 284

    property var wx: null
    readonly property bool ready: root.wx !== null && root.wx.ok === true

    Process {
        id: wxProc

        command: ["python3", Quickshell.shellDir + "/weather.py"]

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
        windows: [ win ]
        active: true

        onCleared: {
            Quickshell.execDetached(["sh", "-c", "date +%s%N > \"${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$1\"", "doiz", "weatherpopup"])
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
            left: root.popX(324, (root.barScrW - 324) / 2)
        }

        implicitWidth: 324
        implicitHeight: (root.ready ? wcol.height + 32 : 120) + 6 + 10

        WlrLayershell.namespace: "doiz-weather-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: card

            x: 6
            y: 0
            width: 312
            height: root.ready ? wcol.height + 32 : 120
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
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
            focus: true
            opacity: 0

            Component.onCompleted: {
                opacity = 1
                y = 10
            }

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            Keys.onEscapePressed: root.closePopup()

            HoverHandler {
                id: cardHover
            }

            Text {
                anchors.centerIn: parent
                visible: !root.ready
                text: root.wx === null ? "Loading weather..." : "Weather unavailable"
                color: root.mutedColor
                font.family: root.mono
                font.pixelSize: 13
            }

            Column {
                id: wcol

                x: 14
                y: 13
                width: root.colW
                spacing: 8
                visible: root.ready

                Text {
                    width: parent.width
                    text: root.ready ? root.wx.city + (root.wx.country ? ", " + root.wx.country : "") : ""
                    color: root.textColor
                    font.family: root.mono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Item {
                    width: parent.width
                    height: 50

                    GlowText {
                        id: wxIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ready ? root.wx.icon : ""
                        glowColor: root.toneB
                        period: 2600
                        color: root.toneB
                        font.family: root.mono
                        font.pixelSize: 38
                    }

                    GlowText {
                        id: wxTemp

                        anchors.left: wxIcon.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.ready ? root.wx.temp + "°" : ""
                        glowColor: root.accentColor
                        blink: false
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 32
                        font.weight: Font.Bold
                    }

                    Column {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        GlowText {
                            anchors.right: parent.right
                            text: root.ready ? root.wx.cond : ""
                            glowColor: root.accentColor
                            period: 3200
                            delay: 400
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.ready ? "H " + root.wx.max + "°  L " + root.wx.min + "°" : ""
                            color: root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 9
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.ready ? "\u2191" + root.wx.sunrise + "  \u2193" + root.wx.sunset : ""
                            color: root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                    }
                }

                Row {
                    spacing: 6

                    Repeater {
                        model: root.ready ? [
                            { k: "feels", v: root.wx.feels + "°", c: root.toneB },
                            { k: "humid", v: root.wx.humidity + "%", c: root.toneB },
                            { k: "wind", v: root.wx.wind + "km/h", c: root.accentColor },
                            { k: "rain", v: root.wx.rain + "%", c: root.accentColor }
                        ] : []

                        delegate: Rectangle {
                            id: chip

                            required property var modelData

                            width: (root.colW - 18) / 4
                            height: 34
                            radius: 8
                            color: root.tint(chip.modelData.c, 0.14)
                            border.width: 1
                            border.color: root.tint(chip.modelData.c, 0.4)

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: chip.modelData.v
                                    color: root.titleColor
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: chip.modelData.k
                                    color: chip.modelData.c
                                    font.family: root.mono
                                    font.pixelSize: 8
                                }
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
                        GradientStop { position: 0.3; color: root.toneB }
                        GradientStop { position: 0.6; color: root.toneB }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Row {
                    Repeater {
                        model: root.ready ? root.wx.hourly : []

                        delegate: Column {
                            id: hr

                            required property var modelData
                            required property int index

                            width: root.colW / 6
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hr.modelData.t
                                color: root.mutedColor
                                font.family: root.mono
                                font.pixelSize: 8
                            }

                            GlowText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hr.modelData.icon
                                glowColor: root.toneB
                                period: 2200
                                delay: hr.index * 260
                                color: root.toneB
                                font.family: root.mono
                                font.pixelSize: 15
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hr.modelData.temp + "°"
                                color: root.titleColor
                                font.family: root.mono
                                font.pixelSize: 10
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

                Row {
                    Repeater {
                        model: root.ready ? root.wx.daily : []

                        delegate: Column {
                            id: dy

                            required property var modelData
                            required property int index

                            width: root.colW / 5
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dy.modelData.day
                                color: root.textColor
                                font.family: root.mono
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }

                            GlowText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dy.modelData.icon
                                glowColor: root.accentColor
                                period: 2800
                                delay: 600 + dy.index * 320
                                color: root.accentColor
                                font.family: root.mono
                                font.pixelSize: 15
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dy.modelData.max + "°"
                                color: root.titleColor
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dy.modelData.min + "°"
                                color: root.mutedColor
                                font.family: root.mono
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

        }
    }
}
