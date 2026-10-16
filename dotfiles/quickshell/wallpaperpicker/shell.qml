import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "."
import "services"
import "components"

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

    property int typeFilter: 0
    property string colorFilter: ""
    property string searchText: ""
    property int sel: 0
    property real pos: 0
    property bool animOn: true
    property bool placed: false
    property bool curDone: false
    property string currentPath: ""
    property bool ready: false
    property bool closing: false
    property bool showOptions: false

    property real optP: root.showOptions ? 1 : 0
    property real chipP: 1

    Behavior on optP {
        NumberAnimation {
            duration: root.showOptions ? 460 : 240
            easing.type: root.showOptions ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.9
        }
    }

    onShowOptionsChanged: chipAnim.restart()

    NumberAnimation {
        id: chipAnim

        target: root
        property: "chipP"
        from: 0
        to: 1
        duration: 520
        easing.type: Easing.OutCubic
    }
    property int quitTicks: 0

    property real introP: 0
    property real spread: 0
    property real pickP: 0
    property real popP: 0
    property real outP: 0
    property bool picking: false
    property real swapP: 1
    property real rollP: 1
    property real stepP: 1
    property bool rolling: false
    property int posDur: 260
    property bool hidden: false
    readonly property real vis: (root.ready && !root.hidden) ? root.introP * (1 - root.outP) : 0
    property real chromeP: 0
    readonly property real chrome: 1 - root.chromeP

    onReadyChanged: {
        if (root.ready && !root.closing) {
            introAnim.restart()
            spreadAnim.restart()
        }
    }

    NumberAnimation {
        id: introAnim

        target: root
        property: "introP"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: spreadAnim

        target: root
        property: "spread"
        from: 0
        to: 1
        duration: 720
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
    }

    SequentialAnimation {
        id: pickSeq

        PropertyAction { target: root; property: "chromeP"; value: 1 }

        ParallelAnimation {
            NumberAnimation { target: root; property: "pickP"; from: 0; to: 1; duration: 480; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "popP"; from: 0; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }

        PauseAnimation { duration: 140 }
        NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 300; easing.type: Easing.InCubic }
        ScriptAction { script: root.finish() }
    }

    SequentialAnimation {
        id: dismissSeq

        NumberAnimation { target: root; property: "outP"; from: 0; to: 1; duration: 240; easing.type: Easing.InCubic }
        ScriptAction { script: root.finish() }
    }

    function roll() {
        root.rolling = true
        root.posDur = 640
        rollAnim.restart()
        rollReset.restart()
    }

    NumberAnimation {
        id: rollAnim

        target: root
        property: "rollP"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutCubic
    }

    Timer {
        id: rollReset

        interval: 720

        onTriggered: {
            root.rolling = false
            root.posDur = 260
        }
    }

    function swap() {
        if (!root.ready || root.closing)
            return

        spreadAnim.duration = 560
        spreadAnim.restart()
        swapAnim.restart()
    }

    NumberAnimation {
        id: swapAnim

        target: root
        property: "swapP"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: stepAnim

        target: root
        property: "stepP"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutCubic
    }

    function dismiss() {
        if (root.closing)
            return

        root.closing = true
        dismissSeq.start()
    }

    function finish() {
        root.hidden = true

        if (root.picking)
            quitTimer.start()
        else
            Qt.quit()
    }

    IpcHandler {
        target: "wallpaperpicker"

        function close(): void {
            if (root.hidden)
                Qt.quit()
            else
                root.dismiss()
        }
    }

    readonly property var items: root.filtered(wp.wallpapers, wp.wallpaperColors, root.typeFilter, root.colorFilter, root.searchText)
    readonly property int count: root.items.length
    readonly property string selPath: root.count > 0 && root.sel < root.count ? String(root.items[root.sel]) : ""

    onSelChanged: {
        if (root.count <= 0) {
            root.pos = root.sel
            return
        }

        var diff = root.sel - root.pos
        diff = ((diff % root.count) + root.count) % root.count

        if (diff > root.count / 2)
            diff -= root.count

        root.pos = root.pos + diff

        if (root.ready && !root.closing && !root.picking && root.count > 1)
            stepAnim.restart()
    }
    onTypeFilterChanged: {
        root.sel = 0
        root.swap()
    }
    onColorFilterChanged: {
        root.sel = 0
        root.swap()
    }
    onSearchTextChanged: root.sel = 0
    onItemsChanged: {
        if (root.placed && root.sel >= root.count)
            root.sel = Math.max(0, root.count - 1)

        root.tryPlace()
    }

    Behavior on pos {
        enabled: root.animOn

        NumberAnimation {
            duration: root.posDur
            easing.type: root.rolling ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.7
        }
    }

    property real glassA: 1.0

    function glass(c) {
        return Qt.rgba(c.r, c.g, c.b, Math.min(c.a, root.glassA))
    }

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function base(p) {
        var s = String(p || "")

        return s.substring(s.lastIndexOf("/") + 1)
    }

    function filtered(list, colors, type, color, query) {
        var src = list || []
        var terms = String(query || "").toLowerCase().split(/\s+/).filter(function (t) { return t !== "" })

        if (type === 0 && color === "" && terms.length === 0)
            return src

        var dir = String(wp.wallpaperDir || "")

        return src.filter(function (item) {
            var path = String(item)
            var video = wp.isVideo(path)

            if (terms.length > 0) {
                var rel = dir !== "" && path.indexOf(dir) === 0 ? path.substring(dir.length) : path
                var hay = rel.toLowerCase()

                for (var k = 0; k < terms.length; k++) {
                    if (hay.indexOf(terms[k]) < 0)
                        return false
                }
            }

            if (type === 1 && video)
                return false

            if (type === 2 && !video)
                return false

            if (color !== "") {
                var tags = (colors || ({}))[path]

                if (!tags || tags.split(",").indexOf(color) < 0)
                    return false
            }

            return true
        })
    }

    function stats(list, colors, type) {
        var out = { all: 0, image: 0, video: 0, colors: ({}) }
        var src = list || []
        var map = colors || ({})

        out.all = src.length

        for (var i = 0; i < src.length; i++) {
            var path = String(src[i])
            var video = wp.isVideo(path)

            if (video)
                out.video++
            else
                out.image++

            if ((type === 1 && video) || (type === 2 && !video))
                continue

            var tags = map[path]

            if (!tags)
                continue

            var parts = tags.split(",")

            for (var j = 0; j < parts.length; j++)
                out.colors[parts[j]] = (out.colors[parts[j]] || 0) + 1
        }

        return out
    }

    function move(d) {
        if (root.count === 0 || root.closing)
            return

        root.sel = ((root.sel + d) % root.count + root.count) % root.count
    }

    function wrap(d) {
        if (root.count === 0 || root.closing)
            return

        root.sel = ((root.sel + d) % root.count + root.count) % root.count
    }

    function randomPick() {
        if (root.count < 2 || root.closing)
            return

        var n = Math.floor(Math.random() * (root.count - 1))

        root.sel = n >= root.sel ? n + 1 : n
    }

    function quickChange() {
        if (root.count < 2 || root.closing || wp.busy)
            return

        var media = wp.autoMedia
        var cand = []

        for (var i = 0; i < root.count; i++) {
            var video = wp.isVideo(root.items[i])

            if (media === "image" && video)
                continue

            if (media === "video" && !video)
                continue

            cand.push(i)
        }

        if (cand.length === 0)
            return

        var target = -1

        if (wp.autoMode === "order") {
            for (var j = 0; j < cand.length; j++) {
                if (cand[j] > root.sel) {
                    target = cand[j]
                    break
                }
            }

            if (target < 0)
                target = cand[0]
        } else {
            var pool = cand.filter(function (k) { return k !== root.sel })

            if (pool.length === 0)
                return

            target = pool[Math.floor(Math.random() * pool.length)]
        }

        root.roll()
        root.sel = target
        wp.apply(root.items[target])
    }

    function tryPlace() {
        if (root.placed || root.closing || !root.curDone || root.count === 0)
            return

        var idx = root.items.indexOf(root.currentPath)

        root.placed = true
        root.animOn = false
        root.sel = idx >= 0 ? idx : 0
        root.pos = root.sel
        root.animOn = true
        root.ready = true
    }

    function choose() {
        if (root.closing || root.selPath === "")
            return

        root.closing = true
        root.picking = true
        wp.apply(root.selPath)
        pickSeq.start()
    }

    Timer {
        id: quitTimer

        interval: 300
        repeat: true

        onTriggered: {
            if (wp.busy && root.quitTicks < 50) {
                root.quitTicks++
                return
            }

            Qt.quit()
        }
    }

    Timer {
        interval: 1500
        running: true

        onTriggered: root.ready = true
    }

    WallpaperService {
        id: wp
    }

    FileView {
        path: wp.stateDir + "/current-wallpaper"

        onLoaded: {
            root.currentPath = text().trim()
            root.curDone = true
            root.tryPlace()
        }

        onLoadFailed: {
            root.curDone = true
            root.tryPlace()
        }
    }

    FileView {
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

        WlrLayershell.namespace: "doiz-wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (root.ready && !root.hidden) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property real pad: 14
        readonly property real headH: 28
        readonly property real capH: 30
        readonly property real footH: 22
        readonly property real stageH: Math.max(260, Math.min(480, height * 0.46))
        readonly property real optH: (optionsBox.height + 14) * Math.max(0, root.optP)
        readonly property real panelW: Math.min(width * 0.9, 1560)
        readonly property real panelH: 2 * pad + headH + 8 + stageH + capH + optH + footH

        FocusScope {
            id: stage

            anchors.fill: parent
            focus: true

            Keys.onPressed: (e) => {
                var typing = searchInput.activeFocus

                if (e.key === Qt.Key_Escape) {
                    if (typing) {
                        searchInput.text = ""
                        searchInput.focus = false
                        stage.forceActiveFocus()
                    } else {
                        root.dismiss()
                    }

                    e.accepted = true
                    return
                }

                if (typing) {
                    if (e.key === Qt.Key_Down) {
                        root.move(1)
                    } else if (e.key === Qt.Key_Up) {
                        root.move(-1)
                    } else if (e.key === Qt.Key_PageDown) {
                        root.move(5)
                    } else if (e.key === Qt.Key_PageUp) {
                        root.move(-5)
                    } else if (e.key === Qt.Key_Tab) {
                        root.wrap(1)
                    } else if (e.key === Qt.Key_Backtab) {
                        root.wrap(-1)
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.choose()
                    } else {
                        return
                    }

                    e.accepted = true
                    return
                }

                if (e.key === Qt.Key_Slash) {
                    searchInput.forceActiveFocus()
                    e.accepted = true
                    return
                }

                if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                    root.move(1)
                } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                    root.move(-1)
                } else if (e.key === Qt.Key_Tab) {
                    root.wrap(1)
                } else if (e.key === Qt.Key_Backtab) {
                    root.wrap(-1)
                } else if (e.key === Qt.Key_PageDown) {
                    root.move(5)
                } else if (e.key === Qt.Key_PageUp) {
                    root.move(-5)
                } else if (e.key === Qt.Key_Home) {
                    root.sel = 0
                } else if (e.key === Qt.Key_End) {
                    root.sel = Math.max(0, root.count - 1)
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    root.choose()
                } else if (e.key === Qt.Key_R) {
                    root.quickChange()
                } else if (e.key === Qt.Key_F) {
                    root.showOptions = !root.showOptions
                } else {
                    return
                }

                e.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                opacity: root.vis

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismiss()
                }
            }

            Rectangle {
                id: panel

                anchors.centerIn: parent
                width: win.panelW
                height: win.panelH
                radius: 10
                color: "transparent"
                border.width: 0
                opacity: root.vis
                scale: (0.90 + 0.10 * root.introP) * (root.picking ? 1 - 0.30 * Math.sqrt(root.outP) : 1 - 0.06 * root.outP)
                transform: Translate { y: 26 * (1 - root.introP) + (root.picking ? 0 : 18) * root.outP }

                MouseArea {
                    anchors.fill: parent
                }

                Item {
                    id: head

                    x: win.pad
                    y: win.pad
                    width: parent.width - 2 * win.pad
                    height: win.headH
                    opacity: Math.min(1, root.introP * 2.2) * root.chrome
                    transform: Translate { y: -10 * (1 - Math.min(1, root.introP * 1.6)) }

                    Rectangle {
                        id: headTile

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: win.headH
                        height: win.headH
                        radius: 8
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.5)
                        color: root.tint(root.accentColor, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉"
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 13
                        }
                    }

                    Text {
                        id: headLabel

                        anchors.left: headTile.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WALLPAPERS"
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.left: headLabel.right
                        anchors.leftMargin: 12
                        anchors.right: searchBox.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: wp.busy ? "Applying…"
                            : (root.count === 0 && wp.colorsBusy && root.colorFilter !== "") ? "Analyzing colors…"
                            : root.base(root.selPath)
                        color: root.titleColor
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: searchBox

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: searchInput.activeFocus || searchInput.text !== "" ? 460 : 380
                        height: win.headH
                        radius: 8
                        color: searchInput.activeFocus ? root.tint(root.accentColor, 0.2) : root.tint(root.accentColor, 0.1)
                        border.width: searchInput.activeFocus ? 2 : 1
                        border.color: root.tint(root.accentColor, searchInput.activeFocus ? 0.95 : 0.55)

                        Behavior on width {
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uDB80\uDF49"
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 15
                        }

                        TextInput {
                            id: searchInput

                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: searchTail.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.titleColor
                            selectionColor: root.accentColor
                            selectedTextColor: root.inkColor
                            font.family: root.mono
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            selectByMouse: true
                            clip: true

                            onTextChanged: root.searchText = searchInput.text
                        }

                        Text {
                            anchors.left: searchInput.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "Search wallpapers…"
                            color: root.textColor
                            opacity: 0.8
                            font.family: root.mono
                            font.pixelSize: 12
                        }

                        Item {
                            id: searchTail

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(keyCap.width, clearBtn.width)
                            height: parent.height

                            Rectangle {
                                id: keyCap

                                anchors.centerIn: parent
                                visible: searchInput.text === "" && !searchInput.activeFocus
                                width: 20
                                height: 18
                                radius: 9
                                color: root.tint(root.accentColor, 0.22)
                                border.width: 1
                                border.color: root.tint(root.accentColor, 0.6)

                                Text {
                                    anchors.centerIn: parent
                                    text: "/"
                                    color: root.accentColor
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                id: clearBtn

                                anchors.centerIn: parent
                                visible: searchInput.text !== ""
                                text: "\uDB80\uDD56"
                                color: clearArea.containsMouse ? root.titleColor : root.accentColor
                                font.family: root.mono
                                font.pixelSize: 14

                                MouseArea {
                                    id: clearArea

                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        searchInput.text = ""
                                        searchInput.focus = false
                                        stage.forceActiveFocus()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: Qt.IBeamCursor
                            onClicked: searchInput.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        id: randomChip

                        anchors.right: optionsChip.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: randomLabel.implicitWidth + 16
                        height: 20
                        radius: 10
                        color: root.rollP < 1 ? root.tint(root.accentColor, 0.28 * (1 - root.rollP))
                            : randomArea.containsMouse ? root.tint(root.accentColor, 0.12) : "transparent"
                        border.width: 1
                        border.color: root.tint(root.accentColor, root.rollP < 1 ? 0.25 + 0.6 * (1 - root.rollP) : 0.25)
                        scale: 1 + 0.18 * Math.sin(root.rollP * Math.PI)
                        rotation: 10 * Math.sin(root.rollP * Math.PI * 3) * (1 - root.rollP)

                        Text {
                            id: randomLabel

                            anchors.centerIn: parent
                            text: wp.autoMode === "order" ? "󰒝  Next  R" : "󰒝  Random  R"
                            color: randomArea.containsMouse ? root.accentColor : root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: randomArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.quickChange()
                        }
                    }

                    Rectangle {
                        id: optionsChip

                        anchors.right: counter.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: optionsLabel.implicitWidth + 16
                        height: 20
                        radius: 10
                        color: root.showOptions ? root.tint(root.accentColor, 0.22)
                            : chipArea.containsMouse ? root.tint(root.accentColor, 0.12) : "transparent"
                        border.width: 1
                        border.color: root.tint(root.accentColor, root.showOptions ? 0.5 : 0.25)
                        scale: 1 + 0.16 * Math.sin(root.chipP * Math.PI)

                        Rectangle {
                            visible: root.chipP < 1
                            anchors.centerIn: parent
                            width: parent.width + 16 * root.chipP
                            height: parent.height + 12 * root.chipP
                            radius: height / 2
                            color: "transparent"
                            border.width: 1
                            border.color: root.tint(root.accentColor, 0.8 * (1 - root.chipP))
                        }

                        Text {
                            id: optionsLabel

                            anchors.centerIn: parent
                            text: "󰒓  Options  F"
                            color: root.showOptions ? root.accentColor : root.mutedColor
                            font.family: root.mono
                            font.pixelSize: 9
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showOptions = !root.showOptions
                        }
                    }

                    Text {
                        id: counter

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.count > 0 ? (root.sel + 1) + " / " + root.count : "0 / 0"
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Item {
                    id: carousel

                    x: win.pad
                    y: win.pad + win.headH + 8
                    width: parent.width - 2 * win.pad
                    height: win.stageH
                    clip: true

                    readonly property real ch: height * 0.88
                    readonly property real cw: Math.min(ch * 16 / 9, width * 0.5)
                    readonly property real chFit: cw * 9 / 16

                    DragHandler {
                        id: dragH

                        property real startPos: 0
                        readonly property real stepPx: carousel.cw * 0.74

                        target: null
                        acceptedButtons: Qt.LeftButton
                        xAxis.enabled: true
                        yAxis.enabled: false

                        onActiveChanged: {
                            if (active) {
                                root.animOn = false
                                startPos = root.pos
                            } else {
                                root.animOn = true

                                if (root.count > 0) {
                                    var r = Math.round(root.pos)
                                    root.sel = ((r % root.count) + root.count) % root.count
                                    root.pos = r
                                }
                            }
                        }

                        onTranslationChanged: {
                            if (active && root.count > 0 && !root.closing)
                                root.pos = startPos - translation.x / stepPx
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.count === 0
                        text: wp.wallpapers.length === 0 ? "No wallpapers in " + wp.wallpaperDir : "No wallpapers match"
                        color: root.mutedColor
                        font.family: root.mono
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: root.items

                        delegate: Item {
                            id: card

                            required property var modelData
                            required property int index

                            readonly property string path: String(card.modelData)
                            readonly property bool on: card.index === root.sel
                            readonly property real rawD: card.index - root.pos
                            readonly property real d: card.rawD - root.count * Math.round(card.rawD / root.count)
                            readonly property real ad: Math.abs(card.d)
                            readonly property bool video: wp.isVideo(card.path)
                            readonly property string thumb: card.video ? String(wp.videoThumbs[card.path] || "") : card.path
                            readonly property bool isCurrent: card.path === root.currentPath
                            readonly property bool picked: root.picking && card.on

                            width: carousel.cw
                            height: carousel.chFit
                            x: carousel.width / 2 - card.width / 2
                               + (card.d < 0 ? -1 : 1) * carousel.cw
                                 * (0.74 * Math.min(card.ad, 1)
                                    + 0.40 * Math.max(0, Math.min(card.ad, 2) - 1)
                                    + 0.24 * Math.max(0, card.ad - 2))
                                 * root.spread * (card.picked ? 1 : 1 - root.pickP)
                            y: (carousel.height - card.height) / 2
                            scale: Math.max(0.4, 1 - 0.22 * card.ad) * (0.78 + 0.22 * Math.min(1, root.spread))
                                   * (card.picked ? 1 + 0.06 * Math.min(1.3, root.popP) : 1 - 0.14 * root.pickP)
                                   * (card.on ? 1 + 0.05 * Math.sin(root.rollP * Math.PI) + 0.04 * Math.sin(root.stepP * Math.PI) : 1)
                            opacity: Math.max(0, 1 - 0.3 * Math.max(0, card.ad - 0.8)) * Math.min(1, root.introP * 2) * (0.3 + 0.7 * root.swapP)
                                     * (card.picked ? 1 : 1 - 0.9 * root.pickP)
                            z: 100 - card.ad * 10
                            visible: card.ad < 3.6

                            Rectangle {
                                visible: card.picked
                                anchors.centerIn: parent
                                width: parent.width + 14 * root.pickP
                                height: parent.height + 14 * root.pickP
                                radius: 8 + 5 * root.pickP
                                color: "transparent"
                                border.width: 2
                                border.color: root.tint(root.accentColor, 0.95 * (1 - root.pickP))
                            }

                            Rectangle {
                                visible: card.on && !root.picking && root.rollP < 1
                                anchors.centerIn: parent
                                width: parent.width + 12 * root.rollP
                                height: parent.height + 12 * root.rollP
                                radius: 8 + 4 * root.rollP
                                color: "transparent"
                                border.width: 2
                                border.color: root.tint(root.accentColor, 0.9 * (1 - root.rollP))
                            }

                            Rectangle {
                                visible: card.on && !root.picking && root.stepP < 1 && root.rollP >= 1 && root.swapP >= 1
                                anchors.centerIn: parent
                                width: parent.width + 10 * root.stepP
                                height: parent.height + 10 * root.stepP
                                radius: 8 + 3 * root.stepP
                                color: "transparent"
                                border.width: 2
                                border.color: root.tint(root.accentColor, 0.75 * (1 - root.stepP))
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 8
                                color: root.cardSolid
                                border.width: 0

                                Loader {
                                    anchors.fill: parent
                                    active: card.ad < 4.5 && card.thumb !== ""

                                    sourceComponent: Image {
                                        source: "file://" + card.thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        sourceSize.width: 800
                                        sourceSize.height: 450
                                        opacity: status === Image.Ready ? 1 : 0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 160 }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: card.video && card.thumb === ""
                                    text: "󰎁"
                                    color: root.mutedColor
                                    font.family: root.mono
                                    font.pixelSize: 28
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#000000"
                                    opacity: Math.min(0.6, 0.24 * card.ad)
                                }

                                Rectangle {
                                    visible: card.video
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    width: vbadge.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(0, 0, 0, 0.55)

                                    Text {
                                        id: vbadge

                                        anchors.centerIn: parent
                                        text: "󰐊 VIDEO"
                                        color: "#ffffff"
                                        font.family: root.mono
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Rectangle {
                                    visible: card.isCurrent
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    width: cbadge.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: root.tint(root.accentColor, 0.85)

                                    Text {
                                        id: cbadge

                                        anchors.centerIn: parent
                                        text: "● CURRENT"
                                        color: root.inkColor
                                        font.family: root.mono
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#ffffff"
                                    opacity: card.on && !root.picking ? 0.3 * Math.max(0, 1 - root.rollP * 2.5) : 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#ffffff"
                                    opacity: card.on && !root.picking && root.rollP >= 1 && root.swapP >= 1 ? 0.12 * Math.max(0, 1 - root.stepP * 2.2) : 0
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "#ffffff"
                                    opacity: card.picked ? 0.5 * Math.max(0, 1 - root.pickP * 2.2) : 0
                                }

                                Item {
                                    visible: card.picked
                                    anchors.centerIn: parent
                                    width: 0
                                    height: 0

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 60 + 280 * root.pickP
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1 + 3 * (1 - root.pickP)
                                        border.color: root.tint(root.accentColor, 0.9 * (1 - root.pickP))
                                    }

                                    Rectangle {
                                        readonly property real p2: Math.max(0, (root.pickP - 0.2) / 0.8)

                                        anchors.centerIn: parent
                                        width: 40 + 200 * p2
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1 + 2 * (1 - p2)
                                        border.color: root.tint(Qt.lighter(root.accentColor, 1.3), 0.8 * (1 - p2))
                                    }

                                    Repeater {
                                        model: 14

                                        delegate: Rectangle {
                                            required property int index

                                            readonly property real ang: index * Math.PI * 2 / 14 + (index % 2) * 0.12
                                            readonly property real dist: (26 + (index % 3) * 14) + (110 + (index % 4) * 24) * root.pickP

                                            width: (index % 3 === 0 ? 8 : 5) * (1 - 0.6 * root.pickP)
                                            height: width
                                            radius: width / 2
                                            x: Math.cos(ang) * dist - width / 2
                                            y: Math.sin(ang) * dist - height / 2
                                            color: index % 3 === 0 ? "#ffffff" : (index % 3 === 1 ? root.accentColor : Qt.lighter(root.accentColor, 1.3))
                                            opacity: Math.min(1, root.pickP * 8) * (1 - root.pickP)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (card.on)
                                        root.choose()
                                    else
                                        root.sel = card.index
                                }
                            }
                        }
                    }
                }

                Text {
                    x: win.pad
                    y: carousel.y + carousel.height + 8
                    width: parent.width - 2 * win.pad
                    height: win.capH - 8
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.selPath === "" ? "" : root.base(root.selPath)
                        + "   ·   " + (wp.isVideo(root.selPath) ? "video" : "image")
                    color: root.textColor
                    font.family: root.mono
                    font.pixelSize: 10
                    elide: Text.ElideMiddle
                }

                Item {
                    x: win.pad
                    y: carousel.y + carousel.height + win.capH
                    width: parent.width - 2 * win.pad
                    height: win.optH
                    clip: true
                    opacity: Math.max(0, Math.min(1, root.optP * 1.4)) * root.chrome

                    Row {
                        id: optionsBox

                        y: 7
                        width: parent.width
                        transform: Translate { y: -16 * (1 - Math.min(1, Math.max(0, root.optP))) }
                        height: Math.max(optSettings.height, optFilters.height)
                        spacing: 24

                        WallpaperSettings {
                            id: optSettings

                            width: Math.min(560, (parent.width - 24) * 0.55)
                            service: wp
                            opacity: Math.max(0, Math.min(1, root.optP * 1.5))
                            transform: Translate { x: -22 * (1 - Math.min(1, Math.max(0, root.optP))) }
                        }

                        WallpaperFilters {
                            id: optFilters

                            width: parent.width - optSettings.width - 24
                            opacity: Math.max(0, Math.min(1, (root.optP - 0.25) * 1.6))
                            transform: Translate { x: 22 * (1 - Math.min(1, Math.max(0, root.optP))) }
                            typeFilter: root.typeFilter
                            colorFilter: root.colorFilter
                            busy: wp.colorsBusy
                            stats: root.stats(wp.wallpapers, wp.wallpaperColors, root.typeFilter)

                            onTypeSelected: function (value) {
                                root.typeFilter = value
                            }

                            onColorSelected: function (value) {
                                root.colorFilter = root.colorFilter === value ? "" : value
                            }
                        }
                    }
                }

                Text {
                    y: parent.height - win.footH - win.pad + 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "←→ / scroll / drag move  ·  R " + (wp.autoMode === "order" ? "next" : "random") + " (uses settings)  ·  / search  ·  Enter apply  ·  F options  ·  Esc cancel"
                    color: root.mutedColor
                    font.family: root.mono
                    font.pixelSize: 8
                    opacity: root.chrome
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property real acc: 0
                    property double lastStep: 0

                    onWheel: (ev) => {
                        var d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x

                        if (d === 0)
                            return

                        if (acc !== 0 && (d < 0) !== (acc < 0))
                            acc = 0

                        acc += d

                        if (Math.abs(acc) < 120)
                            return

                        var now = Date.now()

                        if (now - lastStep >= 140) {
                            root.move(acc < 0 ? 1 : -1)
                            lastStep = now
                        }

                        acc = 0
                    }
                }
            }
        }
    }
}
