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

    property color panelColor: "#ef1b1b1b"
    property color cardSolid: "#2a2a2a"
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#8a8a8a"
    property color inkColor: "#1b1b1b"

    property string wallpaper: ""
    readonly property string wallSource: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
    property var entries: []
    property int sel: 0
    property real pos: 0

    onSelChanged: {
        root.pos = root.sel
        selAnim.restart()
    }

    property real introP: 0
    property real spread: 0
    property real selP: 1
    property real pickP: 0
    property real popP: 0
    property real outP: 0
    property bool picking: false
    property bool hidden: false
    readonly property real vis: root.hidden ? 0 : root.introP * (1 - root.outP)

    NumberAnimation {
        id: introAnim

        target: root
        property: "introP"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: spreadAnim

        target: root
        property: "spread"
        from: 0
        to: 1
        duration: 560
        easing.type: Easing.OutBack
        easing.overshoot: 1.1
    }

    NumberAnimation {
        id: selAnim

        target: root
        property: "selP"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: pickSeq

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickP"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popP"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
        }

        PauseAnimation { duration: 30 }
        NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 240; easing.type: Easing.InCubic }
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
    property bool ready: false
    property bool built: false
    property var snapScreen: null
    property bool closing: false
    property int activeId: 1
    property real monX: 0
    property real monY: 0
    property real monW: 1920
    property real monH: 1080

    readonly property real wheelStep: 60

    Behavior on pos {
        enabled: root.ready

        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    readonly property var current: root.entries.length > 0 ? root.entries[root.sel] : null
    readonly property color selColor: root.current ? Qt.hsla(root.current.hue, 0.6, 0.66, 1) : root.accentColor

    function step(d) {
        var n = root.entries.length

        if (n > 0 && !root.closing)
            root.sel = ((root.sel + d) % n + n) % n
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

    property string rawText: ""
    property int tries: 0

    Timer {
        id: retryTimer

        interval: 100

        onTriggered: root.build(root.rawText)
    }

    function build(text) {
        root.rawText = text

        var parts = text.split("@@")
        var clients = []
        var mons = []

        try {
            clients = JSON.parse(parts[0])
            mons = JSON.parse(parts[2])
        } catch (e) {
            Qt.quit()
            return
        }

        var mon = mons.length > 0 ? mons[0] : null

        for (var m = 0; m < mons.length; m++) {
            if (mons[m].focused)
                mon = mons[m]
        }

        var sc = mon && mon.scale ? mon.scale : 1

        root.monX = mon ? mon.x : 0
        root.monY = mon ? mon.y : 0
        root.monW = mon ? mon.width / sc : 1920
        root.monH = mon ? mon.height / sc : 1080
        root.activeId = mon && mon.activeWorkspace ? mon.activeWorkspace.id : 1

        var list = ToplevelManager.toplevels.values
        var tlMap = {}

        for (var j = 0; j < list.length; j++) {
            var t = list[j]

            if (!t)
                continue

            var k = (t.appId ? String(t.appId) : "") + "|" + (t.title ? String(t.title) : "")

            if (!tlMap[k])
                tlMap[k] = []

            tlMap[k].push(t)
        }

        var byWs = {}
        var any = 0

        for (var i = 0; i < clients.length; i++) {
            var c = clients[i]

            if (!c.mapped || c.hidden || !c.workspace || c.workspace.id <= 0)
                continue

            if (mon && c.monitor !== mon.id)
                continue

            var id = c.workspace.id
            var ck = (c["class"] || "") + "|" + (c.title || "")
            var tl = tlMap[ck] && tlMap[ck].length > 0 ? tlMap[ck].shift() : null

            if (!byWs[id])
                byWs[id] = []

            byWs[id].push({
                tl: tl,
                appId: c["class"] || "",
                title: c.title || "",
                x: c.at[0] - root.monX,
                y: c.at[1] - root.monY,
                w: c.size[0],
                h: c.size[1],
                rank: c.focusHistoryID,
                icon: root.iconOf(c["class"] || ""),
                hue: root.hueOf(c["class"] || c.title || "")
            })
            any++
        }

        if (any > 0 && list.length === 0 && root.tries < 20) {
            root.tries++
            retryTimer.start()
            return
        }

        var ids = []

        for (var key in byWs)
            ids.push(parseInt(key))

        if (ids.indexOf(root.activeId) < 0)
            ids.push(root.activeId)

        ids.sort(function (a, b) { return a - b })

        var last = ids[ids.length - 1]

        if (last < 10)
            ids.push(last + 1)

        var out = []

        for (var n = 0; n < ids.length; n++) {
            var wins = byWs[ids[n]] || []

            wins.sort(function (a, b) { return b.rank - a.rank })

            out.push({
                id: ids[n],
                wins: wins,
                count: wins.length,
                hue: root.hueOf("ws" + ids[n])
            })
        }

        root.entries = out

        var at = 0

        for (var q = 0; q < out.length; q++) {
            if (out[q].id === root.activeId)
                at = q
        }

        var dir = Quickshell.env("WT_DIR")

        root.sel = at

        root.pos = root.sel

        var snap = null
        var screens = Quickshell.screens

        for (var si = 0; si < screens.length; si++) {
            if (mon && screens[si].name === mon.name)
                snap = screens[si]
        }

        root.snapScreen = snap
        root.built = true

        if (snap === null)
            root.reveal()
        else
            revealTimer.start()
    }

    function reveal() {
        if (!root.ready && !root.closing) {
            root.ready = true
            introAnim.restart()
            spreadAnim.restart()
        }
    }

    Timer {
        id: revealTimer

        interval: 500

        onTriggered: root.reveal()
    }

    function choose() {
        if (root.closing)
            return

        root.closing = true
        root.picking = true
        activateTimer.start()
        pickSeq.start()
    }

    Timer {
        id: activateTimer

        interval: 90

        onTriggered: {
            if (root.current && root.current.id !== root.activeId)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + root.current.id + " })"])

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

        root.panelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.94)
        root.cardSolid = Qt.rgba(sf.r, sf.g, sf.b, 1)
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

    Process {
        command: ["sh", "-c", "hyprctl -j clients; echo '@@'; hyprctl -j workspaces; echo '@@'; hyprctl -j monitors"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.build(this.text)
        }
    }

    Process {
        command: ["bash", "-c", "f=$(head -n1 \"${XDG_STATE_HOME:-$HOME/.local/state}/doiz/current-wallpaper\" 2>/dev/null); [ -f \"$f\" ] || exit 0; case \"${f,,}\" in *.mp4|*.webm|*.mkv|*.mov|*.avi) key=$(printf '%s\\n%s' \"$f\" \"$(stat -c %Y \"$f\")\" | md5sum | cut -d' ' -f1); c=\"${XDG_CACHE_HOME:-$HOME/.cache}/doiz\"; full=\"$c/wsoverview-frames/$key.jpg\"; if [ ! -s \"$full\" ]; then mkdir -p \"$c/wsoverview-frames\"; ffmpeg -y -loglevel error -ss 1 -i \"$f\" -vframes 1 -q:v 2 \"$full.tmp.jpg\" >/dev/null 2>&1 || ffmpeg -y -loglevel error -i \"$f\" -vframes 1 -q:v 2 \"$full.tmp.jpg\" >/dev/null 2>&1; [ -s \"$full.tmp.jpg\" ] && mv -f \"$full.tmp.jpg\" \"$full\" || rm -f \"$full.tmp.jpg\"; fi; if [ -s \"$full\" ]; then echo \"$full\"; else t=\"$c/video-thumbs/$key.jpg\"; [ -s \"$t\" ] && echo \"$t\"; fi ;; *) echo \"$f\" ;; esac"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.wallpaper = this.text.trim()
        }
    }

    IpcHandler {
        target: "wsoverview"

        function next(): void {
            root.step(1)
        }

        function prev(): void {
            root.step(-1)
        }
    }

    PanelWindow {
        id: win

        visible: root.built && !root.hidden
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "doiz-ws-overview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (root.ready && !root.closing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property real cardH: Math.round(Math.min(height * 0.58, (width * 0.60) * root.monH / root.monW))
        readonly property real cardW: Math.round(cardH * root.monW / root.monH)
        readonly property real pitch: Math.round(cardH + height * 0.045)

        Rectangle {
            anchors.fill: parent
            opacity: root.vis
            color: root.inkColor

            Image {
                id: bgImg

                anchors.fill: parent
                source: root.wallSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: bgImg
                visible: bgImg.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                autoPaddingEnabled: false
            }

            Rectangle {
                anchors.fill: parent

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.20) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.30) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.20) }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dismiss()

                property real acc: 0

                onWheel: (w) => { w.accepted = false }
            }
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Down || e.key === Qt.Key_Right) {
                    root.step(1)
                    e.accepted = true
                } else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Up || e.key === Qt.Key_Left) {
                    root.step(-1)
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
                if ((e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta) && !e.isAutoRepeat) {
                    root.choose()
                    e.accepted = true
                }
            }
        }

        Item {
            id: stage

            anchors.fill: parent
            opacity: Math.max(0.002, root.vis)

        Repeater {
            model: root.entries

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property real d: index - root.pos
                readonly property real ad: Math.min(1.6, Math.abs(d))
                readonly property bool on: index === root.sel
                readonly property real k: (card.width - 4) / root.monW
                readonly property bool snapOk: snapLoader.item !== null && snapLoader.item.hasContent
                readonly property color c1: Qt.hsla(modelData.hue, 0.6, 0.66, 1)
                readonly property bool picked: root.picking && cell.on

                width: win.cardW
                height: win.cardH
                x: Math.round((win.width - width) / 2)
                y: Math.round((win.height - height) / 2 + d * win.pitch * root.spread)
                scale: (1 - 0.03 * Math.min(1, ad)) * (0.92 + 0.08 * Math.min(1, root.introP))
                       * (cell.on && !root.picking ? 1 + 0.03 * Math.sin(root.selP * Math.PI) : 1)
                       * (cell.picked ? (1 + 0.05 * Math.min(1.3, root.popP)) * (1 + 0.5 * root.outP)
                                      : (1 - 0.10 * root.pickP) * (1 - 0.04 * root.outP))
                opacity: Math.max(0, 1 - 0.28 * ad) * (cell.picked ? 1 : 1 - 0.9 * root.pickP)
                z: 100 - ad * 10
                visible: ad < 1.6

                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 10
                    width: parent.width + 24
                    height: parent.height + 24
                    radius: 14
                    color: Qt.rgba(0, 0, 0, 0.30)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 2
                    height: parent.height + 2
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.38)
                    opacity: cell.on ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 160 }
                    }
                }

                Rectangle {
                    readonly property real kk: cell.picked ? root.pickP : root.selP

                    visible: cell.on && kk < 1 && root.spread >= 0.95
                    anchors.centerIn: parent
                    width: parent.width + (cell.picked ? 22 : 14) * kk
                    height: parent.height + (cell.picked ? 22 : 14) * kk
                    radius: 8 + 6 * kk
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.rgba(cell.c1.r, cell.c1.g, cell.c1.b, (cell.picked ? 0.95 : 0.7) * (1 - kk))
                }

                Rectangle {
                    id: card

                    anchors.fill: parent
                    radius: 6
                    color: root.inkColor
                    border.width: 1
                    border.color: cell.on ? "transparent" : Qt.rgba(1, 1, 1, 0.14)

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        z: 50
                        color: "#ffffff"
                        opacity: cell.picked ? 0.4 * Math.max(0, 1 - root.pickP * 2.2) : 0
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 2
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.wallSource
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.08)
                        }

                        Loader {
                            id: snapLoader

                            anchors.fill: parent
                            active: cell.modelData.id === root.activeId && root.snapScreen !== null

                            sourceComponent: ScreencopyView {
                                captureSource: root.snapScreen
                                live: false
                                paintCursor: false
                                onHasContentChanged: {
                                    if (hasContent)
                                        root.reveal()
                                }
                            }
                        }

                        Repeater {
                            model: cell.snapOk ? [] : cell.modelData.wins.slice().reverse()

                            delegate: Rectangle {
                                id: tile

                                required property var modelData

                                x: modelData.x * cell.k
                                y: modelData.y * cell.k
                                width: Math.max(8, modelData.w * cell.k)
                                height: Math.max(8, modelData.h * cell.k)
                                radius: 8
                                color: root.cardSolid
                                border.width: 1
                                border.color: root.lineColor
                                clip: true

                                readonly property bool hasShot: shotLoader.item !== null && shotLoader.item.hasContent

                                IconImage {
                                    anchors.centerIn: parent
                                    visible: tile.modelData.icon !== "" && !tile.hasShot
                                    source: visible ? Quickshell.iconPath(tile.modelData.icon, true) : ""
                                    implicitSize: Math.max(16, Math.min(48, Math.min(tile.width, tile.height) * 0.5))
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: tile.modelData.icon === "" && !tile.hasShot
                                    text: tile.modelData.appId.length > 0 ? tile.modelData.appId.charAt(0).toUpperCase() : "?"
                                    color: Qt.hsla(tile.modelData.hue, 0.6, 0.66, 1)
                                    font.family: root.mono
                                    font.pixelSize: Math.max(12, Math.min(tile.width, tile.height) * 0.35)
                                    font.weight: Font.Bold
                                }

                                Loader {
                                    id: shotLoader

                                    anchors.fill: parent
                                    active: tile.modelData.tl !== null

                                    sourceComponent: ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: tile.modelData.tl
                                        live: cell.on
                                        paintCursor: false
                                    }
                                }
                            }
                        }
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: false
                    cursorShape: Qt.PointingHandCursor
                    property real acc: 0
                    onClicked: {
                        root.sel = cell.index
                        root.choose()
                    }
                    onWheel: (w) => {
                        acc += w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x

                        while (Math.abs(acc) >= root.wheelStep) {
                            root.step(acc < 0 ? 1 : -1)
                            acc += acc < 0 ? root.wheelStep : -root.wheelStep
                        }

                        w.accepted = true
                    }
                }
            }
        }
        }

        Item {
            anchors.fill: parent
            z: 1000

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                property real acc: 0

                onWheel: (ev) => {
                    acc += ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x

                    while (Math.abs(acc) >= root.wheelStep) {
                        root.step(acc < 0 ? 1 : -1)
                        acc += acc < 0 ? root.wheelStep : -root.wheelStep
                    }
                }
            }
        }

    }
}
