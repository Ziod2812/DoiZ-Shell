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

    readonly property real colW: 224
    readonly property real cellW: 32

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property int todayY: clock.date.getFullYear()
    readonly property int todayM: clock.date.getMonth()
    readonly property int todayD: clock.date.getDate()
    readonly property var cells: calCells(root.viewYear, root.viewMonth)

    readonly property string weekInfo: {
        var d = clock.date
        var start = new Date(d.getFullYear(), 0, 1)
        var doy = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - start) / 86400000) + 1
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        var dn = t.getUTCDay() || 7
        t.setUTCDate(t.getUTCDate() + 4 - dn)
        var y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        var wk = Math.ceil(((t - y0) / 86400000 + 1) / 7)
        return "Week " + wk + "  ·  Day " + doy
    }

    function calCells(y, m) {
        var offset = (new Date(y, m, 1).getDay() + 6) % 7
        var days = new Date(y, m + 1, 0).getDate()
        var prev = new Date(y, m, 0).getDate()
        var out = []

        for (var i = 0; i < 42; i++) {
            var d = i - offset + 1

            if (d < 1)
                out.push({ d: prev + d, cur: false })
            else if (d > days)
                out.push({ d: d - days, cur: false })
            else
                out.push({ d: d, cur: true })
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

    function goToday() {
        root.viewYear = root.todayY
        root.viewMonth = root.todayM
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
            Quickshell.execDetached(["sh", "-c", "date +%s%N > \"${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$1\"", "doiz", "datepopup"])
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
            left: root.popX(276, (root.barScrW - 276) / 2)
        }

        implicitWidth: 276
        implicitHeight: dcol.height + 26 + 12 + 10

        WlrLayershell.namespace: "doiz-date-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: card

            x: 6
            y: 0
            width: 264
            height: dcol.height + 32
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

            Column {
                id: dcol

                x: 16
                y: 13
                width: root.colW
                spacing: 1

                Item {
                    width: parent.width
                    height: hm.implicitHeight

                    GlowText {
                        id: hm

                        text: Qt.formatDateTime(clock.date, "HH")
                        glowColor: root.accentColor
                        blink: false
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 36
                        font.weight: Font.Bold
                    }

                    GlowText {
                        id: hmColon

                        anchors.left: hm.right
                        anchors.baseline: hm.baseline
                        text: ":"
                        glowColor: root.toneB
                        blink: false
                        color: root.toneB
                        opacity: clock.date.getSeconds() % 2 === 0 ? 1 : 0.25
                        font.family: root.mono
                        font.pixelSize: 36
                        font.weight: Font.Bold

                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    GlowText {
                        id: hmMin

                        anchors.left: hmColon.right
                        anchors.baseline: hm.baseline
                        text: Qt.formatDateTime(clock.date, "mm")
                        glowColor: root.accentColor
                        blink: false
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 36
                        font.weight: Font.Bold
                    }

                    GlowText {
                        anchors.left: hmMin.right
                        anchors.leftMargin: 5
                        anchors.baseline: hm.baseline
                        text: Qt.formatDateTime(clock.date, "ss")
                        glowColor: root.toneB
                        period: 2000
                        color: root.toneB
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    color: root.textColor
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    implicitWidth: weekText.implicitWidth + 16
                    implicitHeight: 20
                    radius: 2
                    color: root.tint(root.toneB, 0.16)
                    border.width: 1
                    border.color: root.tint(root.toneB, 0.5)

                    Text {
                        id: weekText
                        anchors.centerIn: parent
                        text: root.weekInfo
                        color: root.toneB
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                Item { width: 1; height: 4 }

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

                Item { width: 1; height: 4 }

                Item {
                    width: parent.width
                    height: 22

                    Rectangle {
                        id: prevBtn

                        width: 22
                        height: 22
                        radius: 8
                        color: prevArea.containsMouse ? root.lineColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            color: root.textColor
                            font.family: root.mono
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    Rectangle {
                        x: 26
                        width: parent.width - 52
                        height: 22
                        radius: 7
                        color: titleArea.containsMouse ? root.lineColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: root.monthNames[root.viewMonth] + " " + root.viewYear
                            color: root.titleColor
                            font.family: root.mono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: titleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.goToday()
                        }
                    }

                    Rectangle {
                        id: nextBtn
                        x: parent.width - 22
                        width: 22
                        height: 22
                        radius: 8
                        color: nextArea.containsMouse ? root.lineColor : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            color: root.textColor
                            font.family: root.mono
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                Row {
                    Repeater {
                        model: root.weekdayNames

                        delegate: Text {
                            required property string modelData
                            required property int index

                            width: root.cellW
                            height: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.toLowerCase()
                            color: index >= 5 ? root.toneB : root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Grid {
                    columns: 7

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

                            width: root.cellW
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
                                text: cell.modelData.d
                                color: cell.isToday ? root.inkColor
                                     : !cell.modelData.cur ? root.mutedColor
                                     : cell.weekend ? root.toneB : root.titleColor
                                opacity: cell.modelData.cur ? 1 : 0.4
                                font.family: root.mono
                                font.pixelSize: 10
                                font.weight: cell.isToday ? Font.Bold : Font.DemiBold
                            }
                        }
                    }
                }
            }

        }
    }
}
