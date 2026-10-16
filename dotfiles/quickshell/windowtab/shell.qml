import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string mono: "JetBrainsMono Nerd Font"

    property color basePanelColor: "#e61b1b1b"
    property color baseCardColor: "#eb2a2a2a"
    property color panelColor: basePanelColor
    property color cardColor: baseCardColor
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#8a8a8a"
    property color inkColor: "#1b1b1b"
    property color backdropColor: "#101010"

    readonly property color selColor: root.accentColor
    readonly property color toneB: Qt.lighter(root.accentColor, 1.3)
    readonly property color hueB: root.shiftHue(root.accentColor, -0.07)
    readonly property color hueC: root.shiftHue(root.accentColor, 0.14)

    property var entries: []
    property int sel: 0
    property bool ready: false
    property bool closing: false

    property real introP: 0
    property real cardsP: 0
    property real selP: 1
    property real pickP: 0
    property real popP: 0
    property real outP: 0
    property bool picking: false
    property bool hidden: false
    readonly property real vis: (root.ready && !root.hidden) ? root.introP * (1 - root.outP) : 0

    onReadyChanged: {
        if (root.ready && !root.closing) {
            introAnim.restart()
            cardsAnim.restart()
        }
    }

    onSelChanged: selAnim.restart()

    NumberAnimation {
        id: introAnim

        target: root
        property: "introP"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: cardsAnim

        target: root
        property: "cardsP"
        from: 0
        to: 1
        duration: 560
    }

    NumberAnimation {
        id: selAnim

        target: root
        property: "selP"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: pickSeq

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickP"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popP"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }

        PauseAnimation { duration: 50 }
        NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: root.finish() }
    }

    SequentialAnimation {
        id: dismissSeq

        NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: root.finish() }
    }

    function dismiss() {
        if (root.closing)
            return

        root.closing = true
        dismissSeq.start()
    }

    function finish() {
        root.hidden = true
        Qt.quit()
    }

    readonly property var current: root.entries.length > 0 ? root.entries[root.sel] : null

    property real glassA: 1.0

    function shiftHue(c, d) {
        var h = ((c.hslHue + d) % 1 + 1) % 1
        return Qt.hsla(h, c.hslSaturation, c.hslLightness, 1)
    }

    function glass(c) {
        return Qt.rgba(c.r, c.g, c.b, Math.min(c.a, root.glassA))
    }

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    FileView {
        id: glassFile

        path: root.cfgHome + "/mycfg/bar-glass"

        onLoaded: {
            var l = text().split("\n")
            var p = parseFloat(l[1])

            if (isNaN(p))
                p = 50

            root.glassA = l[0].trim() === "on" ? Math.max(0.2, Math.min(1, p / 100)) : 1.0
        }

        onLoadFailed: root.glassA = 1.0
    }

    function next() {
        if (root.entries.length > 0 && !root.closing)
            root.sel = (root.sel + 1) % root.entries.length
    }

    function prev() {
        if (root.entries.length > 0 && !root.closing)
            root.sel = (root.sel - 1 + root.entries.length) % root.entries.length
    }

    function hueOf(s) {
        var h = 7

        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360

        return h / 360
    }

    function iconOf(appId) {
        if (!appId)
            return ""

        var entry = DesktopEntries.heuristicLookup(appId)

        if (entry && entry.icon && String(entry.icon).length > 0 && Quickshell.hasThemeIcon(String(entry.icon)))
            return String(entry.icon)

        if (Quickshell.hasThemeIcon(appId))
            return appId

        if (Quickshell.hasThemeIcon(appId.toLowerCase()))
            return appId.toLowerCase()

        if (appId.toLowerCase().indexOf("helium") !== -1) {
            var hn = ["helium", "helium-browser", "net.imput.helium"]

            for (var hi = 0; hi < hn.length; hi++)
                if (Quickshell.hasThemeIcon(hn[hi]))
                    return hn[hi]
        }

        return ""
    }

    property string clientsText: ""
    property int tries: 0

    Timer {
        id: retryTimer

        interval: 100

        onTriggered: root.build(root.clientsText)
    }

    function build(text) {
        root.clientsText = text
        var info = {}

        try {
            var arr = JSON.parse(text)

            for (var i = 0; i < arr.length; i++) {
                var c = arr[i]
                info[(c["class"] || "") + "|" + (c.title || "")] = {
                    addr: c.address || "",
                    r: c.focusHistoryID,
                    ws: c.workspace ? String(c.workspace.name) : ""
                }
            }
        } catch (e) {}

        var list = ToplevelManager.toplevels.values
        var out = []

        for (var j = 0; j < list.length; j++) {
            var t = list[j]

            if (!t || (t.title === undefined && t.appId === undefined))
                continue

            var appId = t.appId ? String(t.appId) : ""
            var meta = info[appId + "|" + (t.title || "")]

            out.push({
                tl: t,
                appId: appId,
                title: t.title ? String(t.title) : appId,
                addr: meta ? meta.addr : "",
                rank: meta ? meta.r : 999,
                ws: meta ? meta.ws : "",
                icon: root.iconOf(appId),
                hue: root.hueOf(appId || String(t.title))
            })
        }

        out.sort(function (a, b) { return a.rank - b.rank })

        var seen = {}
        var grouped = []

        for (var k = 0; k < out.length; k++) {
            var e = out[k]
            var key = e.appId + "|" + (e.ws !== "" ? e.ws : e.title)

            if (seen[key] !== undefined) {
                grouped[seen[key]].count++
                continue
            }

            e.count = 1
            seen[key] = grouped.length
            grouped.push(e)
        }

        out = grouped

        root.entries = out

        if (out.length === 0) {
            if (root.tries < 20) {
                root.tries++
                retryTimer.start()
            } else {
                Qt.quit()
            }

            return
        }

        if (Quickshell.env("WT_DIR") === "prev")
            root.sel = out.length - 1
        else
            root.sel = out.length > 1 ? 1 : 0

        root.ready = true
    }

    property var pick: null

    function choose() {
        if (root.closing)
            return

        root.closing = true
        root.picking = true
        root.pick = root.current

        activateTimer.start()
        pickSeq.start()
    }

    Timer {
        id: activateTimer

        interval: 90

        onTriggered: {
            if (root.pick) {
                root.pick.tl.activate()

                if (root.pick.addr !== "")
                    Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + root.pick.addr])
            }
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
        root.backdropColor = Qt.darker(bg, 1.6)
    }

    Process {
        command: ["sh", "-c", "cat \"$1/theme/theme.conf\" 2>/dev/null", "doiz", root.cfgHome]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    Process {
        command: ["hyprctl", "-j", "clients"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.build(this.text)
        }
    }

    IpcHandler {
        target: "windowtab"

        function next(): void {
            root.next()
        }

        function prev(): void {
            root.prev()
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

    PanelWindow {
        id: win

        visible: root.ready && !root.hidden
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "doiz-window-tab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (root.ready && !root.closing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property int n: root.entries.length
        readonly property real gap: 10
        readonly property real pad: 16
        readonly property real gm: 16
        readonly property real chrome: 34
        readonly property real ratio: 0.60
        readonly property real headH: 26
        readonly property real footH: 22
        readonly property real availW: width * 0.88 - 2 * pad
        readonly property real availH: height * 0.86 - 2 * pad - headH - footH - 16

        function fit(c) {
            var r = 1
            var wByW = (win.availW - (c - 1) * win.gap) / c
            var hPer = (win.availH - (r - 1) * win.gap) / r
            var wByH = (hPer - win.chrome) / win.ratio

            return Math.max(120, Math.min(380, wByW, wByH))
        }

        readonly property int maxCols: 5

        readonly property int cols: Math.max(1, Math.min(win.n, win.maxCols))
        readonly property int rows: 1
        readonly property real cardW: win.fit(win.cols)
        readonly property real previewH: win.cardW * win.ratio
        readonly property real cardH: win.previewH + win.chrome
        readonly property real gridW: win.cols * win.cardW + (win.cols - 1) * win.gap
        readonly property real gridH: win.rows * win.cardH + (win.rows - 1) * win.gap

        property int first: 0

        function syncFirst() {
            var f = win.first

            if (root.sel < f)
                f = root.sel
            else if (root.sel >= f + win.maxCols)
                f = root.sel - win.maxCols + 1

            win.first = Math.max(0, Math.min(Math.max(0, win.n - win.maxCols), f))
        }

        Connections {
            target: root

            function onSelChanged() { win.syncFirst() }
            function onEntriesChanged() { win.syncFirst() }
        }

        Component.onCompleted: win.syncFirst()

        function move(d) {
            if (win.n === 0 || root.closing)
                return

            var t = root.sel + d

            if (t >= 0 && t < win.n)
                root.sel = t
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.backdropColor.r, root.backdropColor.g, root.backdropColor.b, 0.55)
            opacity: root.vis

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()
            }
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Tab) {
                    root.next()
                    e.accepted = true
                } else if (e.key === Qt.Key_Backtab) {
                    root.prev()
                    e.accepted = true
                } else if (e.key === Qt.Key_Right) {
                    win.move(1)
                    e.accepted = true
                } else if (e.key === Qt.Key_Left) {
                    win.move(-1)
                    e.accepted = true
                } else if (e.key === Qt.Key_Down) {
                    root.next()
                    e.accepted = true
                } else if (e.key === Qt.Key_Up) {
                    root.prev()
                    e.accepted = true
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    root.choose()
                    e.accepted = true
                } else if (e.key === Qt.Key_Escape) {
                    root.dismiss()
                    e.accepted = true
                }
            }

            Keys.onReleased: (e) => {
                if (e.key === Qt.Key_Alt && !e.isAutoRepeat) {
                    root.choose()
                    e.accepted = true
                }
            }
        }

        Rectangle {
            id: panel

            anchors.centerIn: parent
            width: win.gridW + 2 * win.pad
            height: win.gridH + 2 * win.pad + win.headH + win.footH + 16
            radius: 12
            color: root.glass(root.panelColor)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, Math.min(0.45, root.glassA))
            opacity: root.vis
            scale: (0.92 + 0.08 * root.introP) * (1 - 0.05 * root.outP)
            transform: Translate { y: 20 * (1 - root.introP) + 14 * root.outP }

            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 9000
            }

            Item {
                x: win.pad
                y: win.pad
                width: parent.width - 2 * win.pad
                height: win.headH
                opacity: Math.min(1, root.introP * 2)

                Rectangle {
                    id: headTile

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: win.headH
                    height: win.headH
                    radius: 8
                    color: root.tint(root.selColor, 0.16)
                    border.width: 1
                    border.color: root.tint(root.selColor, 0.5)

                    Text {
                        anchors.centerIn: parent
                        text: "󰖲"
                        color: root.selColor
                        font.family: root.mono
                        font.pixelSize: 13
                    }
                }

                Text {
                    id: headLabel

                    anchors.left: headTile.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WINDOWS"
                    color: root.mutedColor
                    font.family: root.mono
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Text {
                    anchors.left: headLabel.right
                    anchors.leftMargin: 12
                    anchors.right: counter.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.current ? root.current.title : ""
                    color: root.titleColor
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: counter

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: counterText.implicitWidth + 16
                    radius: 10
                    color: root.tint(root.selColor, 0.16 + 0.2 * Math.sin(root.selP * Math.PI))
                    border.width: 1
                    border.color: root.tint(root.selColor, 0.5)
                    scale: 1 + 0.18 * Math.sin(root.selP * Math.PI)

                    Text {
                        id: counterText

                        anchors.centerIn: parent
                        text: (root.sel + 1) + " / " + win.n
                        color: root.selColor
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }

            Item {
                id: grid

                clip: true
                x: win.pad - win.gm
                y: win.pad + win.headH + 8 - win.gm
                width: win.gridW + 2 * win.gm
                height: win.gridH + 2 * win.gm

                Repeater {
                    model: root.entries

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool on: index === root.sel
                        readonly property bool inView: index >= win.first && index < win.first + win.maxCols

                        readonly property bool picked: root.picking && cell.on
                        readonly property real rank: Math.max(0, cell.index - win.first)
                        readonly property real introT: Math.max(0, Math.min(1, (root.cardsP - cell.rank * 0.09) / 0.55))
                        readonly property real introE: 1 - Math.pow(1 - cell.introT, 3)
                        property real hi: cell.on ? 1 : 0

                        Behavior on hi {
                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                        }

                        z: cell.on ? 10 : 0
                        x: win.gm + (index - win.first) * (win.cardW + win.gap)
                        y: win.gm
                        opacity: inView ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on x {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }

                        width: win.cardW
                        height: win.cardH

                        Rectangle {
                            id: card

                            anchors.fill: parent
                            radius: 8
                            opacity: cell.introE * (cell.picked ? 1 : 1 - 0.85 * root.pickP)
                            scale: (0.82 + 0.18 * cell.introE) * (1 + 0.04 * cell.hi)
                                   * (cell.picked ? 1 + 0.05 * Math.min(1.3, root.popP) : 1 - 0.10 * root.pickP)
                            transform: Translate { y: 24 * (1 - cell.introE) }
                            color: cell.on ? root.tint(root.selColor, 0.16) : root.cardColor
                            border.width: 1
                            border.color: cell.on ? root.tint(root.selColor, 0.6) : root.lineColor

                            Behavior on color {
                                ColorAnimation { duration: 160 }
                            }

                            Item {
                                x: 10
                                y: 0
                                width: parent.width - 20
                                height: win.chrome

                                Rectangle {
                                    id: iconBox

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 22
                                    radius: 6
                                    color: root.tint(root.selColor, 0.16)

                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: cell.modelData.icon !== ""
                                        source: visible ? Quickshell.iconPath(cell.modelData.icon, true) : ""
                                        implicitSize: 18
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: cell.modelData.icon === ""
                                        text: cell.modelData.appId.length > 0 ? cell.modelData.appId.charAt(0).toUpperCase() : "?"
                                        color: root.selColor
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    anchors.left: iconBox.right
                                    anchors.leftMargin: 8
                                    anchors.right: badges.left
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: cell.modelData.title
                                    color: cell.on ? root.titleColor : root.textColor
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Row {
                                    id: badges

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Rectangle {
                                        visible: cell.modelData.count > 1
                                        width: Math.max(20, cntText.implicitWidth + 12)
                                        height: 18
                                        radius: 9
                                        color: root.tint(root.selColor, 0.16)
                                        border.width: 1
                                        border.color: root.tint(root.selColor, 0.5)

                                        Text {
                                            id: cntText

                                            anchors.centerIn: parent
                                            text: "×" + cell.modelData.count
                                            color: root.selColor
                                            font.family: root.mono
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Rectangle {
                                        visible: cell.modelData.ws !== ""
                                        width: Math.max(20, wsText.implicitWidth + 12)
                                        height: 18
                                        radius: 9
                                        color: root.tint(root.mutedColor, 0.18)
                                        border.width: 1
                                        border.color: root.tint(root.mutedColor, 0.5)

                                        Text {
                                            id: wsText

                                            anchors.centerIn: parent
                                            text: cell.modelData.ws
                                            color: root.textColor
                                            font.family: root.mono
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                            }

                            ClippingRectangle {
                                x: 6
                                y: win.chrome
                                width: parent.width - 12
                                height: win.previewH - 6
                                radius: 6
                                color: root.inkColor

                                readonly property bool hasShot: shot.item !== null && shot.item.hasContent

                                IconImage {
                                    anchors.centerIn: parent
                                    visible: cell.modelData.icon !== "" && !parent.hasShot
                                    source: visible ? Quickshell.iconPath(cell.modelData.icon, true) : ""
                                    implicitSize: Math.max(32, Math.min(80, win.previewH * 0.4))
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: cell.modelData.icon === "" && !parent.hasShot
                                    text: cell.modelData.appId.length > 0 ? cell.modelData.appId.charAt(0).toUpperCase() : "?"
                                    color: root.mutedColor
                                    font.family: root.mono
                                    font.pixelSize: Math.max(28, win.previewH * 0.35)
                                    font.weight: Font.Bold
                                }

                                Loader {
                                    id: shot

                                    anchors.fill: parent
                                    active: cell.modelData.tl !== null

                                    sourceComponent: ScreencopyView {
                                        captureSource: cell.modelData.tl
                                        live: cell.on
                                        paintCursor: false

                                        readonly property real sw: sourceSize.width > 0 ? sourceSize.width : 16
                                        readonly property real sh: sourceSize.height > 0 ? sourceSize.height : 10
                                        readonly property real k: Math.min(parent.width / sw, parent.height / sh)

                                        anchors.centerIn: parent
                                        width: sw * k
                                        height: sh * k
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#ffffff"
                                opacity: cell.picked ? 0.45 * Math.max(0, 1 - root.pickP * 2.2) : 0
                            }

                            Rectangle {
                                readonly property real k: cell.picked ? root.pickP : root.selP

                                visible: cell.on && k < 1 && root.cardsP >= 1
                                anchors.centerIn: parent
                                width: parent.width + (cell.picked ? 12 : 8) * k
                                height: parent.height + (cell.picked ? 12 : 8) * k
                                radius: 8 + 4 * k
                                color: "transparent"
                                border.width: 2
                                border.color: root.tint(root.accentColor, (cell.picked ? 0.95 : 0.7) * (1 - k))
                            }

                            Loader {
                                anchors.fill: parent
                                active: cell.on

                                sourceComponent: GradBorder {
                                    rr: 8
                                    c1: root.accentColor
                                    c2: root.toneB
                                    c3: root.accentColor
                                    c4: root.toneB
                                    cycle: 7000
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: cell.inView
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.sel = cell.index
                            onClicked: {
                                root.sel = cell.index
                                root.choose()
                            }
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0

                onWheel: (ev) => {
                    acc += ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x

                    while (Math.abs(acc) >= 60) {
                        if (acc < 0)
                            root.next()
                        else
                            root.prev()

                        acc += acc < 0 ? 60 : -60
                    }
                }
            }

            Text {
                y: panel.height - win.footH - win.pad + 4
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tab next  ·  Shift+Tab back  ·  ←→ move  ·  Enter open  ·  Esc cancel"
                color: root.mutedColor
                font.family: root.mono
                font.pixelSize: 8
            }
        }
    }
}
