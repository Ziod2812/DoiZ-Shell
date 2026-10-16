import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

ShellRoot {
    id: root

    readonly property string scripts: Theme.configHome + "/hypr/scripts"
    readonly property int barH: 36
    readonly property int ear: 24

    property bool peeking: false
    property string cavaText: "            "
    property string weatherText: "󰖐 --"
    property bool weatherOk: false
    property int tempC: -1
    property int brightness: -1
    property string netKind: "down"
    property string netName: ""

    function run(args) {
        Quickshell.execDetached(args)
    }

    readonly property var spotifyCandidate: {
        var ps = Mpris.players.values
        var browsers = ["chromium", "chrome", "vivaldi", "brave", "firefox", "librewolf", "zen", "opera", "edge", "floorp", "waterfox"]
        for (var i = 0; i < ps.length; i++) {
            var bus = (ps[i].dbusName || "").toLowerCase()
            var desk = (ps[i].desktopEntry || "").toLowerCase()
            var id = (ps[i].identity || "").toLowerCase()
            var isBrowser = false
            for (var b = 0; b < browsers.length; b++) {
                if (bus.indexOf(browsers[b]) >= 0 || desk.indexOf(browsers[b]) >= 0 || id.indexOf(browsers[b]) >= 0) {
                    isBrowser = true
                    break
                }
            }
            if (isBrowser)
                continue
            if (/^org\.mpris\.mediaplayer2\.spotify(\.|$)/.test(bus) || desk === "spotify" || desk === "com.spotify.client")
                return ps[i]
        }
        return null
    }

    property bool spotifyAlive: true
    readonly property var spotify: root.spotifyAlive ? root.spotifyCandidate : null

    Process {
        id: spotifyCheck

        command: ["pgrep", "-x", "spotify"]

        onExited: (exitCode, exitStatus) => root.spotifyAlive = exitCode === 0
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.spotifyCandidate !== null
        triggeredOnStart: true

        onTriggered: {
            if (!spotifyCheck.running)
                spotifyCheck.running = true
        }
    }

    Process {
        id: spotifyKill

        command: ["pkill", "-x", "spotify"]
    }

    Timer {
        id: spotKillTimer

        interval: 1500
        repeat: false

        onTriggered: {
            if (root.spotifyCandidate !== null && !spotifyKill.running)
                spotifyKill.running = true
        }
    }

    readonly property var spotifyEntries: {
        var sp = root.spotify
        if (!sp)
            return []
        var playing = sp.playbackState === MprisPlaybackState.Playing
        var list = [
            { t: playing ? "Pause" : "Play", a: "toggle", g: playing ? "\u23f8" : "\u25b6" },
            { t: "Next", a: "next", g: "\u23ed" },
            { t: "Previous", a: "previous", g: "\u23ee" }
        ]
        if (sp.shuffleSupported)
            list.push({ t: "Shuffle", a: "shuffle", g: "\u21c4", toggle: true, on: sp.shuffle })
        if (sp.loopSupported) {
            var ls = sp.loopState
            list.push({
                t: ls === MprisLoopState.Track ? "Repeat: track" : (ls === MprisLoopState.Playlist ? "Repeat: playlist" : "Repeat: off"),
                a: "loop",
                g: ls === MprisLoopState.Track ? "\u21ba" : "\u21bb",
                toggle: true,
                on: ls !== MprisLoopState.None
            })
        }
        if (sp.canRaise)
            list.push({ t: "Show Spotify", a: "raise", g: "\u25a3" })
        if (sp.canQuit)
            list.push({ t: "Quit Spotify", a: "quit", g: "\u2715" })
        return list
    }

    property bool spotMenu: false

    function spotAction(a) {
        var sp = root.spotify
        if (!sp)
            return
        if (a === "toggle") sp.togglePlaying()
        else if (a === "next") root.spotSkip(1)
        else if (a === "previous") root.spotSkip(-1)
        else if (a === "shuffle" && sp.shuffleSupported) sp.shuffle = !sp.shuffle
        else if (a === "loop" && sp.loopSupported) {
            var ls = sp.loopState
            sp.loopState = ls === MprisLoopState.None ? MprisLoopState.Playlist
                         : (ls === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
        }
        else if (a === "raise") sp.raise()
        else if (a === "quit") {
            sp.quit()
            spotKillTimer.restart()
        }
    }

    property bool spotWasLate: false

    function spotSkip(dir) {
        var sp = root.spotify
        if (!sp || spotLock.running)
            return

        spotLock.restart()

        if (dir > 0) {
            sp.next()
        } else {
            root.spotWasLate = sp.position > 3
            sp.previous()
            if (root.spotWasLate)
                spotPrevTimer.restart()
        }
    }

    Timer {
        id: spotLock

        interval: 400
        repeat: false
    }

    Timer {
        id: spotPrevTimer

        interval: 180
        repeat: false

        onTriggered: {
            if (root.spotify)
                root.spotify.previous()
        }
    }

    function openSpotMenu(bar, icon) {
        root.trayItem = null
        root.trayCurrent = null
        root.trayScreen = bar.screen
        root.trayX = icon.mapToItem(null, icon.width / 2, 0).x + 8
        root.spotMenu = true
    }

    property var trayItem: null
    property var trayCurrent: null
    property var trayStack: []
    property var trayScreen: null
    property real trayX: 0

    function openTrayMenu(item, bar, icon) {
        root.spotMenu = false
        root.trayStack = []
        root.trayCurrent = item.menu
        root.trayScreen = bar.screen
        root.trayX = icon.mapToItem(null, icon.width / 2, 0).x + 8
        root.trayItem = item
    }

    function closeTrayMenu() {
        root.spotMenu = false
        root.trayItem = null
        root.trayCurrent = null
        root.trayStack = []
    }

    function openAt(item, args) {
        var x = Math.round(item.mapToItem(null, item.width / 2, 0).x + 8)
        root.run(["sh", "-c",
            'printf "%s %s" "$1" "$(date +%s%3N)" > "${XDG_RUNTIME_DIR:-/tmp}/doiz-bar-anchor"; shift; exec "$@"',
            "sh", String(x)].concat(args))
    }

    function panel(item, name) {
        var args = ["bash", root.scripts + "/doiz-panel.sh", name]
        if (item)
            root.openAt(item, args)
        else
            root.run(args)
    }

    IpcHandler {
        target: "bar"

        function peek(ms: int): void {
        }

        function hide(): void {
            peekTimer.stop()
            root.peeking = true
        }

        function show(): void {
            peekTimer.stop()
            root.peeking = false
        }
    }

    Timer {
        id: peekTimer
        onTriggered: root.peeking = false
    }

    onPeekingChanged: {
        if (root.peeking) {
            peekTimer.interval = 15000
            peekTimer.restart()
        }
    }

    property string lastMediaPos: ""

    Timer {
        interval: 800
        repeat: true
        running: true
        onTriggered: {
            if (!mprisChip.visible || mprisChip.width <= 0)
                return
            var cx = Math.round(mprisChip.mapToItem(null, mprisChip.width / 2, 0).x + 8)
            var w = Math.max(120, Math.round(mprisChip.width))
            var key = cx + "/" + w
            if (key === root.lastMediaPos)
                return
            root.lastMediaPos = key
            root.run(["sh", "-c",
                'mkdir -p "$1/mycfg"; printf "center=%s\\nwidth=%s\\n" "$2" "$3" > "$1/mycfg/mediapopup.conf"; ' +
                'qs -c mediapopup ipc call mediapopup place "$2" "$3" >/dev/null 2>&1',
                "doiz", Theme.configHome, String(cx), String(w)])
        }
    }

    Process {
        id: cavaProc
        running: true
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]

        stdout: SplitParser {
            onRead: data => {
                var icons = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
                var p = data.split(";")
                var s = ""
                for (var i = 0; i < p.length; i++) {
                    if (p[i] === "")
                        continue
                    var n = parseInt(p[i])
                    if (isNaN(n))
                        n = 0
                    s += icons[Math.max(0, Math.min(7, n))]
                }
                if (s !== "")
                    root.cavaText = s
            }
        }

        onRunningChanged: {
            if (!running)
                cavaRestart.restart()
        }
    }

    Timer {
        id: cavaRestart
        interval: 2000
        onTriggered: cavaProc.running = true
    }

    Process {
        id: weatherProc
        command: ["bash", Quickshell.shellDir + "/weather.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var lines = this.text.trim().split("\n")
                    var o = JSON.parse(lines[lines.length - 1])
                    root.weatherText = o.text || "󰖐 --"
                    root.weatherOk = o["class"] !== "unavailable"
                } catch (e) {
                    root.weatherText = "󰖐 --"
                    root.weatherOk = false
                }
            }
        }
    }

    Timer {
        interval: 1800000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!weatherProc.running)
                weatherProc.running = true
        }
    }

    Process {
        id: tempProc
        command: ["cat", "/sys/class/thermal/thermal_zone0/temp"]

        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text)
                root.tempC = isNaN(v) ? -1 : Math.round(v / 1000)
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!tempProc.running)
                tempProc.running = true
        }
    }

    Process {
        id: blProc
        command: ["brightnessctl", "-m", "info"]

        stdout: StdioCollector {
            onStreamFinished: {
                var f = this.text.trim().split(",")
                var v = f.length >= 4 ? parseInt(f[3]) : NaN
                root.brightness = isNaN(v) ? -1 : v
            }
        }
    }

    Timer {
        id: blTimer
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!blProc.running)
                blProc.running = true
        }
    }

    Process {
        id: netProc
        command: ["bash", Quickshell.shellDir + "/net.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim()
                var i = s.indexOf("|")
                root.netKind = i > 0 ? s.substring(0, i) : "down"
                root.netName = i > 0 ? s.substring(i + 1) : ""
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running)
                netProc.running = true
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    readonly property int volumePct:
        root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) : 0
    readonly property bool volumeMuted:
        root.sink && root.sink.audio ? root.sink.audio.muted : false

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: root.bat !== null && root.bat !== undefined && root.bat.isPresent && root.bat.isLaptopBattery
    readonly property int batPct: root.hasBattery ? Math.round(root.bat.percentage * 100) : 0
    readonly property bool batCharging: root.hasBattery && root.bat.state === UPowerDeviceState.Charging

    readonly property var player: {
        var ps = Mpris.players.values
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].playbackState === MprisPlaybackState.Playing)
                return ps[i]
        }
        return ps.length > 0 ? ps[0] : null
    }

    readonly property bool playerVisible:
        root.player !== null && root.player.playbackState !== MprisPlaybackState.Stopped

    readonly property bool playerPlaying:
        root.player !== null && root.player.playbackState === MprisPlaybackState.Playing

    readonly property string playerText: {
        if (!root.player)
            return ""
        var t = root.player.trackTitle || ""
        if (root.player.trackArtist)
            t += " - " + root.player.trackArtist
        if (t.length > 40)
            t = t.substring(0, 39) + "…"
        return (root.playerPlaying ? "󰐊" : "󰏤") + " " + t
    }

    readonly property var workspaceList: {
        var src = Hyprland.workspaces.values
        var out = []
        for (var i = 0; i < src.length; i++) {
            if (src[i].id > 0)
                out.push(src[i])
        }
        out.sort(function (a, b) { return a.id - b.id })
        return out
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                left: 8
                right: 8
            }

            implicitHeight: root.barH
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.barH

            WlrLayershell.namespace: "doiz-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {
                item: pill

                Region { item: sideCava }
            }

            Item {
                id: scene

                width: parent.width
                height: root.barH
                y: root.peeking ? -root.barH : 0
                opacity: root.peeking ? 0 : 1

                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }

                Item {
                    id: sideCava

                    visible: Theme.cavaPos !== "center"
                    width: visible ? sideBars.width + 12 : 0
                    height: 22
                    y: 10
                    x: Theme.cavaPos.indexOf("left") === 0 ? 0 : scene.width - width

                    Cava {
                        id: sideBars
                        anchors.centerIn: parent
                        bars: root.cavaText
                    }
                }

                Item {
                    id: pill

                    readonly property real w: content.implicitWidth + 20 + 2 * root.ear

                    width: w
                    height: root.barH
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: -1
                            fillColor: Theme.panel

                            startX: 0
                            startY: 0

                            PathLine { x: pill.w; y: 0 }
                            PathArc {
                                x: pill.w - root.ear
                                y: root.ear
                                radiusX: root.ear
                                radiusY: root.ear
                                direction: PathArc.Counterclockwise
                            }
                            PathLine { x: pill.w - root.ear; y: root.barH - 12 }
                            PathArc {
                                x: pill.w - root.ear - 12
                                y: root.barH
                                radiusX: 12
                                radiusY: 12
                                direction: PathArc.Clockwise
                            }
                            PathLine { x: root.ear + 12; y: root.barH }
                            PathArc {
                                x: root.ear
                                y: root.barH - 12
                                radiusX: 12
                                radiusY: 12
                                direction: PathArc.Clockwise
                            }
                            PathLine { x: root.ear; y: root.ear }
                            PathArc {
                                x: 0
                                y: 0
                                radiusX: root.ear
                                radiusY: root.ear
                                direction: PathArc.Counterclockwise
                            }
                        }
                    }

                    Row {
                        id: content

                        x: root.ear + 10
                        y: 10
                        height: 22
                        spacing: 2

                        Chip {
                            id: launcherChip

                            text: "\uf011"
                            color: Theme.accent
                            fontSize: 13
                            onClicked: root.run(["bash", root.scripts + "/doiz-popup.sh", "powermenu"])
                        }

                        ModeIcon {
                            id: modeIcon

                            onActivated: index => {
                                if (index === 0)
                                    root.openAt(modeIcon, ["bash", root.scripts + "/doiz-popup.sh", "dashboard"])
                                else if (index === 1)
                                    root.openAt(modeIcon, ["bash", root.scripts + "/doiz-popup.sh", "dock"])
                                else
                                    root.run(["sh", "-c", "qs -c settings ipc call settings toggle || qs -c settings -n &"])
                            }
                        }

                        Row {
                            id: wsRow

                            height: 22
                            spacing: 4
                            leftPadding: 4
                            rightPadding: 10

                            Repeater {
                                model: root.workspaceList

                                delegate: Item {
                                    id: ws

                                    required property var modelData

                                    readonly property bool act: modelData.focused
                                    readonly property bool urgent: modelData.urgent === true

                                    width: act ? 30 : (wsArea.containsMouse ? 22 : 16)
                                    height: 22

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: ws.act ? 380 : 320
                                            easing.type: ws.act ? Easing.OutBack : Easing.OutCubic
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 14
                                        radius: ws.act ? 6 : 5
                                        color: ws.urgent ? Theme.red
                                            : ws.act ? Theme.accentAlt
                                            : wsArea.containsMouse ? Theme.accentAltHover
                                            : "transparent"

                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "●"
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: ws.act || ws.urgent ? Theme.bg
                                            : wsArea.containsMouse ? Theme.fg
                                            : Theme.muted
                                        opacity: ws.act || wsArea.containsMouse ? 1 : 0.75
                                    }

                                    MouseArea {
                                        id: wsArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.run(["hyprctl", "dispatch",
                                            "hl.dsp.focus({ workspace = " + ws.modelData.id + " })"])
                                    }
                                }
                            }
                        }

                        Chip {
                            id: dateChip

                            text: Qt.formatDateTime(clock.date, dateChip.hovered ? "ddd dd MMM" : "HH:mm")
                            color: Theme.accentAlt
                            bold: true
                            onClicked: root.openAt(dateChip, ["bash", root.scripts + "/doiz-popup.sh", "datepopup"])
                        }

                        Chip {
                            id: weatherChip

                            text: root.weatherText
                            color: root.weatherOk ? Theme.accent : Theme.muted
                            bold: true
                            onClicked: root.openAt(weatherChip, ["bash", root.scripts + "/doiz-popup.sh", "weatherpopup"])
                        }

                        Chip {
                            id: mprisChip

                            property real glow: 1

                            visible: root.playerVisible
                            text: root.playerText
                            color: root.playerPlaying ? Theme.accent : Theme.muted
                            bold: true
                            opacity: root.playerPlaying && !hovered ? glow : 1

                            SequentialAnimation {
                                loops: Animation.Infinite
                                running: root.playerPlaying && mprisChip.visible

                                NumberAnimation { target: mprisChip; property: "glow"; to: 1; duration: 2200; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 300 }
                                NumberAnimation { target: mprisChip; property: "glow"; to: 0.2; duration: 2200; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 300 }
                            }

                            onClicked: button => {
                                if (button === Qt.RightButton) {
                                    if (root.player)
                                        root.player.togglePlaying()
                                } else if (button === Qt.MiddleButton) {
                                    if (root.player)
                                        root.player.next()
                                } else {
                                    root.run(["bash", root.scripts + "/doiz-mediapopup", "toggle"])
                                }
                            }
                        }

                        Cava {
                            visible: Theme.cavaPos === "center"
                            bars: root.cavaText
                        }

                        Row {
                            id: drawer

                            property bool open: false

                            height: 22

                            Chip {
                                text: "󰇘"
                                onClicked: drawer.open = !drawer.open
                            }

                            Item {
                                id: reveal

                                height: 22
                                clip: true
                                width: drawer.open ? more.implicitWidth : 0

                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }

                                Row {
                                    id: more

                                    height: 22
                                    spacing: 2

                                    Row {
                                        id: trayRow

                                        readonly property int shown: {
                                            var items = SystemTray.items.values
                                            var n = 0
                                            for (var i = 0; i < items.length; i++) {
                                                if (items[i].status !== Status.Passive)
                                                    n++
                                            }
                                            return n
                                        }

                                        visible: shown > 0 || root.spotify !== null
                                        height: 22
                                        spacing: 7
                                        leftPadding: 5
                                        rightPadding: 5

                                        Item {
                                            id: spotIcon

                                            visible: root.spotify !== null
                                            width: visible ? 22 : 0
                                            height: 22

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 7
                                                color: Theme.green
                                                opacity: spotMouse.containsMouse ? 0.28 : 0

                                                Behavior on opacity {
                                                    NumberAnimation { duration: 120 }
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf1bc"
                                                color: root.spotify && root.spotify.playbackState === MprisPlaybackState.Playing
                                                       ? Theme.green : Theme.muted
                                                font.family: Theme.font
                                                font.pixelSize: 14

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }
                                            }

                                            MouseArea {
                                                id: spotMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.RightButton)
                                                        root.openSpotMenu(win, spotIcon)
                                                    else if (mouse.button === Qt.MiddleButton)
                                                        root.spotify.togglePlaying()
                                                    else if (root.spotify.canRaise)
                                                        root.spotify.raise()
                                                    else
                                                        root.spotify.togglePlaying()
                                                }

                                                onWheel: wheel => {
                                                    if (wheel.angleDelta.y > 0) root.spotSkip(1)
                                                    else if (wheel.angleDelta.y < 0) root.spotSkip(-1)
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: SystemTray.items

                                            delegate: Item {
                                                id: trayItem

                                                required property var modelData

                                                visible: modelData.status !== Status.Passive
                                                width: visible ? 22 : 0
                                                height: 22

                                                function showMenu() {
                                                    if (modelData.hasMenu) {
                                                        root.openTrayMenu(modelData, win, trayItem)
                                                    } else {
                                                        var pt = trayItem.mapToItem(null, 0, trayItem.height)
                                                        modelData.display(win, pt.x, pt.y)
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 7
                                                    color: Theme.accentAlt
                                                    opacity: trayMouse.containsMouse ? 0.28 : 0

                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 120 }
                                                    }
                                                }

                                                IconImage {
                                                    anchors.centerIn: parent
                                                    implicitSize: 13
                                                    source: trayItem.modelData.icon
                                                }

                                                MouseArea {
                                                    id: trayMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                                    onClicked: mouse => {
                                                        if (mouse.button === Qt.RightButton
                                                                || (mouse.button === Qt.LeftButton && trayItem.modelData.onlyMenu)) {
                                                            trayItem.showMenu()
                                                        } else if (mouse.button === Qt.MiddleButton) {
                                                            trayItem.modelData.secondaryActivate()
                                                        } else {
                                                            trayItem.modelData.activate()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Chip {
                                        id: tempChip

                                        visible: root.tempC >= 0
                                        text: " " + root.tempC + "°"
                                        color: root.tempC >= 80 ? Theme.red : Theme.cyan
                                        onClicked: root.panel(tempChip, "sysinfo")
                                    }

                                    Chip {
                                                                                text: root.netKind === "wifi" ? "󰖩 " + root.netName
                                            : root.netKind === "ethernet" ? "󰈀"
                                            : "󰖪"
                                        color: Theme.accentAlt
                                        onClicked: root.panel(null, "network")
                                    }

                                    Chip {
                                                                                visible: root.brightness >= 0
                                        text: "󰃠 " + root.brightness + "%"
                                        onClicked: root.panel(null, "brightness")
                                        onScrolled: dy => {
                                            root.run(["brightnessctl", "set", dy > 0 ? "5%+" : "5%-"])
                                            blTimer.restart()
                                            if (!blProc.running)
                                                blProc.running = true
                                        }
                                    }

                                    Chip {
                                                                                text: root.volumeMuted ? "󰖁" : "󰕾 " + root.volumePct + "%"
                                        onClicked: root.panel(null, "volume")
                                    }

                                    Chip {
                                                                                visible: root.hasBattery
                                        text: (root.batCharging ? "󰂄 " : "󰁹 ") + root.batPct + "%"
                                        color: root.batCharging ? Theme.green : Theme.subtext
                                        onClicked: root.panel(null, "battery")
                                    }

                                    Chip {
                                        text: "󰕮"
                                        onClicked: button => {
                                            if (button === Qt.RightButton)
                                                root.run(["sh", "-c", "qs -c settings ipc call settings toggle || qs -c settings -n &"])
                                            else
                                                root.run(["bash", root.scripts + "/doiz-controlcenter", "ipc", "call", "controlcenter", "toggle"])
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

    PanelWindow {
        id: trayWin

        visible: (root.trayItem !== null && root.trayCurrent !== null) || root.spotMenu
        screen: root.trayScreen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        WlrLayershell.namespace: "doiz-tray-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Shortcut {
            sequences: ["Escape"]
            onActivated: root.closeTrayMenu()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeTrayMenu()
        }

        Rectangle {
            id: menuBox

            visible: root.trayItem !== null

            x: Math.max(8, Math.min(trayWin.width - width - 8, root.trayX - width / 2))
            y: root.barH + 2

            width: 240
            height: menuCol.implicitHeight + 12

            radius: 10
            color: Theme.panel
            border.width: 1
            border.color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.45)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            QsMenuOpener {
                id: opener

                menu: root.trayCurrent
            }

            Column {
                id: menuCol

                x: 6
                y: 6
                width: parent.width - 12
                spacing: 2

                Item {
                    visible: root.trayStack.length > 0
                    width: parent.width
                    height: visible ? 28 : 0

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Theme.accentAlt
                        opacity: backMouse.containsMouse ? 0.3 : 0
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: "\u2039  Back"
                        color: Theme.subtext
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: backMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            var st = root.trayStack.slice()
                            root.trayCurrent = st.pop()
                            root.trayStack = st
                        }
                    }
                }

                Repeater {
                    model: opener.children

                    delegate: Item {
                        id: row

                        required property var modelData

                        width: menuCol.width
                        height: modelData.isSeparator ? 9 : 28

                        Rectangle {
                            visible: row.modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: 1
                            color: Theme.muted
                            opacity: 0.4
                        }

                        Rectangle {
                            visible: !row.modelData.isSeparator
                            anchors.fill: parent
                            radius: 6
                            color: Theme.accentAlt
                            opacity: rowMouse.containsMouse && row.modelData.enabled ? 0.3 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }
                        }

                        Text {
                            visible: !row.modelData.isSeparator
                                     && row.modelData.buttonType !== QsMenuButtonType.None
                            anchors.verticalCenter: parent.verticalCenter
                            x: 8
                            width: 14
                            text: row.modelData.checkState === Qt.Checked ? "\u2713" : ""
                            color: Theme.green
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        IconImage {
                            visible: !row.modelData.isSeparator && row.modelData.icon !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            x: 24
                            implicitSize: 14
                            source: row.modelData.icon
                        }

                        Text {
                            visible: !row.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: row.modelData.icon !== "" ? 44 : 26
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            text: row.modelData.text.replace(/_/g, "")
                            elide: Text.ElideRight
                            color: row.modelData.enabled ? Theme.fg : Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: !row.modelData.isSeparator && row.modelData.hasChildren
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            text: "\u203a"
                            color: Theme.subtext
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !row.modelData.isSeparator && row.modelData.enabled
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (row.modelData.hasChildren) {
                                    root.trayStack = root.trayStack.concat([root.trayCurrent])
                                    root.trayCurrent = row.modelData
                                } else {
                                    row.modelData.triggered()
                                    root.closeTrayMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: spotBox

            visible: root.spotMenu

            x: Math.max(8, Math.min(trayWin.width - width - 8, root.trayX - width / 2))
            y: root.barH + 2

            width: 220
            height: spotCol.implicitHeight + 12

            radius: 10
            color: Theme.panel
            border.width: 1
            border.color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.5)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Column {
                id: spotCol

                x: 6
                y: 6
                width: parent.width - 12
                spacing: 2

                Text {
                    width: parent.width
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 4
                    bottomPadding: 6
                    elide: Text.ElideRight
                    text: root.spotify
                          ? ((root.spotify.trackTitle || "Spotify") + (root.spotify.trackArtist ? " - " + root.spotify.trackArtist : ""))
                          : "Spotify"
                    color: Theme.subtext
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Repeater {
                    model: root.spotifyEntries

                    delegate: Item {
                        id: spotRow

                        required property var modelData

                        width: spotCol.width
                        height: 28

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Theme.green
                            opacity: spotRowMouse.containsMouse ? 0.25 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            width: 16
                            text: spotRow.modelData.g
                            color: Theme.green
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 34
                            text: spotRow.modelData.t
                            color: spotRow.modelData.on ? Theme.green : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            visible: spotRow.modelData.toggle === true && spotRow.modelData.on === true
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.green
                        }

                        MouseArea {
                            id: spotRowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.spotAction(spotRow.modelData.a)
                                if (spotRow.modelData.toggle !== true)
                                    root.closeTrayMenu()
                            }
                        }
                    }
                }
            }
        }
    }
}
