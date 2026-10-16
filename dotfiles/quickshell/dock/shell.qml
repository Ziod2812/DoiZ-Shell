import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

ShellRoot {
    id: root

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
    readonly property string mono: "JetBrainsMono Nerd Font"

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

    property string dockMode: "dock"
    property string dockPos: "left"
    property bool dockShown: false
    property bool keepOpen: false
    property string wantPos: "left"
    property bool moving: false
    property bool swapping: false
    property bool modeSwitching: false
    readonly property bool stays: root.keepOpen && root.dockMode === "dock"
    readonly property int reserveZone: 42
    readonly property bool appMode: root.dockMode === "app"
    readonly property bool horiz: root.dockPos === "bottom" || root.appMode
    readonly property string placePos: root.appMode ? "bottom" : root.dockPos
    readonly property real placeGap: root.appMode ? 130 : 80
    readonly property real winW: root.horiz ? dockCard.width + 330 : 330
    readonly property real winH: root.horiz ? 130 : dockCard.height + 8
    property var pinned: []
    property bool pickerOpen: false
    readonly property bool popupMode: root.dockMode === "popup"
    readonly property real popLeft: root.popX(324, (root.barScrW - 324) / 2)
    readonly property real belowTop: 30 + 10 + popCard.height + 6

    property bool closing: false
    property bool notesOpen: false
    onNotesOpenChanged: if (!root.notesOpen) root.saveNotes()
    readonly property bool notesShown: root.notesOpen && !root.closing

    function closePopup() {
        if (root.closing)
            return

        root.closing = true
        root.saveNotes()
        dockCard.opacity = 0
        root.dockShown = false
        popCard.opacity = 0
        popCard.y = 0
        appBack.opacity = 0
        quitTimer.start()
    }

    function afterLaunch() {
        if (!root.stays)
            root.closePopup()
    }

    function escPressed() {
        if (!root.stays) {
            root.closePopup()
            return
        }

        if (root.notesOpen)
            root.notesOpen = false
        else if (root.pickerOpen)
            root.pickerOpen = false
    }

    function toggleKeep() {
        root.keepOpen = !root.keepOpen
        root.hov = -1
        root.persist()
    }

    Timer {
        id: quitTimer

        interval: 200
        onTriggered: Qt.quit()
    }

    IpcHandler {
        target: "popup"

        function close(): void {
            root.closePopup()
        }
    }

    property real pulse: 0

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "pulse"; to: 1; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "pulse"; to: 0; duration: 2200; easing.type: Easing.InOutSine }
    }

    property color panelColor: "#f51b1b1b"
    property color cardColor: "#942a2a2a"
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#8a8a8a"
    property color inkColor: "#1b1b1b"
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
    }

    Process {
        command: ["sh", "-c", "cat \"$1/theme/theme.conf\" 2>/dev/null", "doiz", root.cfgHome]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseTheme(this.text)
        }
    }

    readonly property string scr: "$HOME/.config/hypr/scripts/"
    readonly property var fnCatalog: [
        { fid: "launcher", g: "\uf00a", tip: "Launcher", cmd: ["sh", "-c", "qs -c launcher ipc call launcher toggle || qs -c launcher &"] },
        { fid: "clipboard", g: "\uf0ea", tip: "Clipboard", cmd: ["sh", "-c", "qs -c clipboard ipc call clipboard toggle || qs -c clipboard -n &"] },
        { fid: "notes", g: "\uf040", tip: "Notes", special: "notes" },
        { fid: "settings", g: "\uf013", tip: "Settings", cmd: ["sh", "-c", "qs -c settings ipc call settings toggle || qs -c settings -n &"] },
        { fid: "controlcenter", g: "\uf0f3", tip: "Control center", cmd: ["sh", "-c", root.scr + "doiz-controlcenter ipc call controlcenter toggle"] },
        { fid: "dashboard", g: "\uf009", tip: "Dashboard", cmd: ["sh", "-c", "bash " + root.scr + "doiz-popup.sh dashboard"] },
        { fid: "wallpaper", g: "\uf03e", tip: "Wallpaper", cmd: ["sh", "-c", root.scr + "doiz-wallpaperpicker.sh"] },
        { fid: "screenshot", g: "\uf030", tip: "Screenshot", cmd: ["sh", "-c", "sleep 0.4; " + root.scr + "screenshot.sh"] },
        { fid: "screenshotarea", g: "\uf125", tip: "Screenshot area", cmd: ["sh", "-c", "sleep 0.3; " + root.scr + "screenshot-area.sh"] },
        { fid: "network", g: "\uf1eb", tip: "Network", cmd: ["sh", "-c", "bash " + root.scr + "doiz-panel.sh network"] },
        { fid: "volume", g: "\uf028", tip: "Volume", cmd: ["sh", "-c", "bash " + root.scr + "doiz-panel.sh volume"] },
        { fid: "brightness", g: "\uf185", tip: "Brightness", cmd: ["sh", "-c", "bash " + root.scr + "doiz-panel.sh brightness"] },
        { fid: "battery", g: "\uf240", tip: "Battery", cmd: ["sh", "-c", "bash " + root.scr + "doiz-panel.sh battery"] },
        { fid: "sysinfo", g: "\uf2db", tip: "System info", cmd: ["sh", "-c", "bash " + root.scr + "doiz-panel.sh sysinfo"] },
        { fid: "keybinds", g: "\uf11c", tip: "Keybinds", cmd: ["sh", "-c", "qs -c keybinds ipc call keybinds toggle || qs -c keybinds -n &"] },
        { fid: "overview", g: "\uf24d", tip: "Workspaces", cmd: ["sh", "-c", root.scr + "doiz-wsoverview.sh next"] },
        { fid: "lock", g: "\uf023", tip: "Lock", cmd: ["sh", "-c", "sleep 0.3; " + root.scr + "lock.sh"] },
        { fid: "power", g: "\uf011", tip: "Power menu", cmd: ["sh", "-c", "bash " + root.scr + "doiz-popup.sh powermenu"] }
    ]

    function fnFor(fid) {
        for (var i = 0; i < root.fnCatalog.length; i++) {
            if (root.fnCatalog[i].fid === fid)
                return root.fnCatalog[i]
        }

        return null
    }

    readonly property string dockConf: root.dataHome + "/doiz/dock.conf"
    readonly property int maxItems: 12

    property var layout: ["fn:launcher", "fn:clipboard", "fn:notes"]

    function entryFor(id) {
        var apps = DesktopEntries.applications.values

        for (var i = 0; i < apps.length; i++) {
            if (String(apps[i].id) === id)
                return apps[i]
        }

        return null
    }

    readonly property var allItems: {
        var out = []

        for (var i = 0; i < root.layout.length; i++) {
            var key = root.layout[i]

            if (key.indexOf("fn:") === 0) {
                var f = root.fnFor(key.substring(3))

                if (f)
                    out.push({ key: key, drag: true, kind: f.special || "cmd", g: f.g, tip: f.tip, cmd: f.cmd })
            } else if (key.indexOf("app:") === 0) {
                var e = root.entryFor(key.substring(4))

                if (e)
                    out.push({ key: key, drag: true, kind: "app", id: key.substring(4), tip: String(e.name), icon: String(e.icon || "") })
            }
        }

        if (out.length > 0)
            out.push({ sep: true })

        out.push({ key: "home", g: "\uf015", tip: "Home", kind: "cmd", cmd: ["thunar", Quickshell.env("HOME")] })
        out.push({ key: "terminal", g: "\uf120", tip: "Terminal", kind: "cmd", cmd: ["kitty"] })
        out.push({ sep: true })
        if (!root.appMode)
            out.push({ key: "add", g: "\uf067", tip: "Add app / function", kind: "add" })

        if (root.dockMode === "dock")
            out.push({ key: "pos", g: "\uf047", tip: "Position: " + root.dockPos + " (click to move)", kind: "pos" })

        if (root.dockMode === "dock")
            out.push({ key: "keep", g: "\uf08d", tip: root.keepOpen ? "Keep open: ON" : "Keep open: OFF", kind: "keep" })

        out.push({ key: "mode", g: root.popupMode ? "\uf009" : (root.appMode ? "\uf0db" : "\uf2d0"), tip: root.popupMode ? "App grid mode" : (root.appMode ? "Dock mode" : "Popup mode"), kind: "mode" })
        return out
    }

    readonly property var tiles: root.allItems.filter(function (i) { return i.sep !== true })
    readonly property var dashItems: root.tiles.filter(function (i) { return i.kind !== "add" && i.kind !== "pos" })
    readonly property int nDrag: root.allItems.filter(function (i) { return i.drag === true }).length

    function persist() {
        var t = "v=2\nmode=" + root.dockMode + "\npos=" + root.wantPos + "\nkeep=" + (root.keepOpen ? "1" : "0") + "\n"

        for (var i = 0; i < root.layout.length; i++)
            t += "item=" + root.layout[i] + "\n"

        dockFile.setText(t)
    }

    function loadConf(text) {
        var ls = String(text).split("\n")
        var items = []
        var v2 = false

        for (var i = 0; i < ls.length; i++) {
            var l = ls[i].trim()

            if (l === "v=2")
                v2 = true
            else if (l.indexOf("mode=") === 0)
                root.dockMode = (l.substring(5) === "popup" || l.substring(5) === "app") ? l.substring(5) : "dock"
            else if (l.indexOf("keep=") === 0)
                root.keepOpen = l.substring(5) === "1"
            else if (l.indexOf("pos=") === 0)
            {
                root.dockPos = (l.substring(4) === "right" || l.substring(4) === "bottom") ? l.substring(4) : "left"
                root.wantPos = root.dockPos
            }
            else if (l.indexOf("item=") === 0 && l.length > 5)
                items.push(l.substring(5))
            else if (l.indexOf("app=") === 0 && l.length > 4)
                items.push("app:" + l.substring(4))
        }

        if (v2)
            root.layout = items
        else
            root.layout = ["fn:launcher", "fn:clipboard", "fn:notes"].concat(items)
    }

    function addKey(key) {
        if (root.layout.indexOf(key) < 0 && root.layout.length < root.maxItems) {
            root.layout = root.layout.concat([key])
            root.persist()
        }
    }

    function removeKey(key) {
        root.layout = root.layout.filter(function (x) { return x !== key })
        root.hov = -1
        root.persist()
    }

    function moveItem(from, to) {
        var a = root.layout.slice()
        var fi = a.indexOf(root.allItems[from].key)
        var ti = a.indexOf(root.allItems[to].key)

        if (fi < 0 || ti < 0 || fi === ti)
            return

        a.splice(ti, 0, a.splice(fi, 1)[0])
        root.layout = a
    }

    function cyclePos() {
        if (root.moving || root.closing)
            return

        root.moving = true
        root.wantPos = root.dockPos === "left" ? "bottom" : (root.dockPos === "bottom" ? "right" : "left")
        root.notesOpen = false
        root.pickerOpen = false
        root.hov = -1
        root.dockShown = false
        root.persist()
        retractTimer.start()
    }

    Timer {
        id: retractTimer

        interval: 230
        onTriggered: {
            if (root.closing)
                return

            root.swapping = true
            root.dockPos = root.wantPos
            growTimer.start()
        }
    }

    Timer {
        id: growTimer

        interval: 160
        onTriggered: {
            if (root.closing)
                return

            root.swapping = false
            root.dockShown = true
            root.moving = false
        }
    }

    function toggleMode() {
        root.modeSwitching = true
        modeTimer.restart()
        dockGrab.active = false
        root.dockMode = root.dockMode === "dock" ? "popup" : (root.dockMode === "popup" ? "app" : "dock")
        root.pickerOpen = false
        root.hov = -1
        root.persist()
        regrabTimer.restart()
    }

    onStaysChanged: dockGrab.active = !root.stays && !root.closing

    Timer {
        id: modeTimer

        interval: 500
        onTriggered: root.modeSwitching = false
    }

    Timer {
        id: regrabTimer

        interval: 120
        onTriggered: dockGrab.active = !root.stays && !root.closing
    }

    function isOn(it) {
        return (it.kind === "notes" && root.notesOpen) || (it.kind === "add" && root.pickerOpen) || (it.kind === "keep" && root.keepOpen)
    }

    property int hov: -1
    property int pressIdx: -1
    property int pressBtn: 0
    property bool dragging: false
    property real pressX: 0
    property real pressY: 0

    function railAt(y) {
        var acc = 0

        for (var i = 0; i < root.allItems.length; i++) {
            var h = root.allItems[i].sep === true ? 8 : 40

            if (y >= acc && y < acc + h)
                return root.allItems[i].sep === true ? -1 : i

            acc += h + 6
        }

        return -1
    }

    function railTarget(y) {
        var acc = 0

        for (var i = 0; i < root.allItems.length; i++) {
            var h = root.allItems[i].sep === true ? 8 : 40

            if (y < acc + h)
                return Math.max(0, Math.min(i, root.nDrag - 1))

            acc += h + 6
        }

        return Math.max(0, root.nDrag - 1)
    }

    function gridCell(x, y) {
        var col = Math.max(0, Math.min(3, Math.floor(x / 72)))
        var row = Math.max(0, Math.floor(y / 70))
        return row * 4 + col
    }

    function gridAt(x, y) {
        if (x < 0 || y < 0 || x % 72 >= 68 || y % 70 >= 66 || x >= 288)
            return -1

        var i = root.gridCell(x, y)
        return i < root.tiles.length ? i : -1
    }

    function gridTarget(x, y) {
        return Math.max(0, Math.min(root.gridCell(x, y), root.nDrag - 1))
    }

    function dragStart(idx, x, y, btn) {
        root.pressIdx = idx
        root.pressBtn = btn
        root.pressX = x
        root.pressY = y
        root.dragging = false
    }

    function dragMove(x, y, target) {
        if (root.pressIdx < 0 || root.pressBtn !== Qt.LeftButton || root.pressIdx >= root.nDrag)
            return

        if (!root.dragging && Math.abs(x - root.pressX) + Math.abs(y - root.pressY) > 8)
            root.dragging = true

        if (root.dragging && target !== root.pressIdx) {
            root.moveItem(root.pressIdx, target)
            root.pressIdx = target
            root.hov = target
        }
    }

    function dragEnd(list, idx, btn) {
        var was = root.dragging
        var p = root.pressIdx

        root.pressIdx = -1
        root.dragging = false

        if (was) {
            root.persist()
            return
        }

        if (p < 0 || p !== idx || p >= list.length)
            return

        if (btn === Qt.RightButton)
            root.secondary(list[p])
        else
            root.activate(list[p])
    }

    function launchKey(key) {
        if (key.indexOf("fn:") === 0) {
            var f = root.fnFor(key.substring(3))

            if (!f)
                return

            if (f.special === "notes") {
                root.notesOpen = !root.notesOpen
                return
            }

            Quickshell.execDetached(f.cmd)
            root.closePopup()
            return
        }

        var e = root.entryFor(key.substring(4))

        if (e)
            e.execute()

        root.closePopup()
    }

    function togglePin(key) {
        if (root.layout.indexOf(key) >= 0)
            root.removeKey(key)
        else
            root.addKey(key)
    }

    function secondary(it) {
        if (it.drag === true)
            root.removeKey(it.key)
    }

    function activate(it) {
        if (it.kind === "notes") {
            root.pickerOpen = false
            root.notesOpen = !root.notesOpen
            return
        }

        if (it.kind === "add") {
            root.notesOpen = false
            root.pickerOpen = !root.pickerOpen
            return
        }

        if (it.kind === "mode") {
            root.toggleMode()
            return
        }

        if (it.kind === "keep") {
            root.toggleKeep()
            return
        }

        if (it.kind === "pos") {
            root.cyclePos()
            return
        }

        if (it.kind === "app") {
            var e = root.entryFor(it.id)

            if (e)
                e.execute()

            root.afterLaunch()
            return
        }

        Quickshell.execDetached(it.cmd)
        root.afterLaunch()
    }

    FileView {
        id: dockFile

        path: root.dockConf
        printErrors: false
        blockLoading: true
        blockWrites: true
        onLoaded: root.loadConf(dockFile.text())
    }

    property string pickQuery: ""

    readonly property var pickList: {
        var q = root.pickQuery.trim().toLowerCase()
        var out = []

        for (var k = 0; k < root.fnCatalog.length; k++) {
            var f = root.fnCatalog[k]

            if (q === "" || f.tip.toLowerCase().indexOf(q) >= 0)
                out.push({ key: "fn:" + f.fid, name: f.tip, g: f.g, isFn: true, icon: "" })
        }

        var apps = DesktopEntries.applications.values
        var al = []

        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]

            if (a.noDisplay)
                continue

            if (q === "" || String(a.name).toLowerCase().indexOf(q) >= 0)
                al.push({ key: "app:" + String(a.id), name: String(a.name), g: "", isFn: false, icon: String(a.icon || "") })
        }

        al.sort(function (x, y) { return x.name.localeCompare(y.name) })
        return out.concat(al)
    }

    readonly property string notesDir: root.dataHome + "/doiz"
    readonly property string notesPath: root.notesDir + "/notes.txt"
    property bool notesReady: false

    Process {
        command: ["mkdir", "-p", root.notesDir]
        running: true
    }

    FileView {
        id: notesFile

        path: root.notesPath
        printErrors: false
        blockLoading: true
        blockWrites: true
        onLoaded: {
            editor.text = notesFile.text()
            root.notesReady = true
        }
        onLoadFailed: root.notesReady = true
    }

    function saveNotes() {
        if (root.notesReady)
            notesFile.setText(editor.text)
    }

    Timer {
        id: saveTimer

        interval: 600
        onTriggered: root.saveNotes()
    }

    component DockBtn: Item {
        id: db

        property var it
        property bool compact: true
        property bool on: false
        property bool hover: false
        property bool lifted: false
        readonly property bool hot: db.on || db.hover || db.lifted
        readonly property bool isApp: db.it !== undefined && db.it.kind === "app"

        implicitWidth: compact ? 40 : 68
        implicitHeight: compact ? 40 : 66
        opacity: db.lifted ? 0.8 : 1
        scale: db.lifted ? 1.08 : 1

        Behavior on scale { NumberAnimation { duration: 90 } }

        Rectangle {
            id: face

            x: db.compact ? 0 : (parent.width - width) / 2
            width: db.compact ? parent.width : 44
            height: db.compact ? parent.height : 44
            radius: 8
            color: db.hot ? "transparent" : root.cardColor
            gradient: db.hot ? hotGrad : null

            Gradient {
                id: hotGrad

                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.accentColor }
                GradientStop { position: 1.0; color: root.toneB }
            }

            layer.enabled: db.hot
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: root.accentColor
                shadowBlur: 1.0
                shadowOpacity: 0.35 + 0.55 * root.pulse
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Text {
                anchors.centerIn: parent
                visible: !db.isApp
                text: db.it && !db.isApp ? db.it.g : ""
                color: db.hot ? root.inkColor : root.textColor
                font.family: root.mono
                font.pixelSize: 15
            }

            IconImage {
                anchors.centerIn: parent
                visible: db.isApp
                width: 24
                height: 24
                source: db.isApp ? Quickshell.iconPath(db.it.icon, "application-x-executable") : ""
            }
        }

        Text {
            visible: !db.compact
            x: 0
            y: 48
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: db.it ? db.it.tip : ""
            color: db.hot ? root.titleColor : root.textColor
            font.family: root.mono
            font.pixelSize: 8
        }

        Rectangle {
            visible: db.compact && db.hover && !root.dragging
            x: root.horiz ? (parent.width - width) / 2 : (root.dockPos === "right" ? -width - 18 : parent.width + 18)
            y: root.horiz ? -height - 14 : (parent.height - height) / 2
            width: tipText.implicitWidth + 20
            height: 24
            radius: 3
            color: root.panelColor
            border.width: 1
            border.color: root.tint(root.accentColor, 0.5)

            Text {
                id: tipText

                anchors.centerIn: parent
                text: db.it ? db.it.tip : ""
                color: root.accentColor
                font.family: root.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    HyprlandFocusGrab {
        id: dockGrab

        windows: [dockWin, popWin, appWin, notesWin, pickerWin]
        active: !root.stays

        onCleared: {
            if (root.modeSwitching) {
                regrabTimer.restart()
                return
            }

            Quickshell.execDetached(["sh", "-c", "date +%s%N > \"${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$1\"", "doiz", "dock"])
            root.closePopup()
        }
    }

    PanelWindow {
        id: dockWin

        visible: root.dockMode === "dock"
        color: "transparent"
        exclusionMode: root.stays && root.dockShown ? ExclusionMode.Normal : ExclusionMode.Ignore
        exclusiveZone: root.stays && root.dockShown && !root.closing ? root.reserveZone : 0
        mask: Region { item: dockCard }

        anchors {
            left: root.dockPos === "left"
            right: root.dockPos === "right"
            bottom: root.dockPos === "bottom"
        }

        margins {
            left: 0
            right: 0
            bottom: 0
        }

        implicitWidth: root.winW
        implicitHeight: root.winH

        WlrLayershell.namespace: "doiz-dock"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: dockCard

            x: root.dockPos === "left" ? (root.dockShown ? -12 : -72)
                : (root.dockPos === "right" ? (root.dockShown ? root.winW - 56 : root.winW + 4)
                : (root.winW - width) / 2)
            y: root.dockPos === "bottom" ? (root.dockShown ? root.winH - 56 : root.winH + 4) : 0
            width: root.horiz ? dockCol.width + 16 : 68
            height: root.horiz ? 68 : dockCol.height + 16
            radius: 12
            color: root.panelColor
            border.width: 1
            border.color: root.tint(root.accentColor, 0.3 + 0.4 * root.pulse)
            focus: true
            opacity: 0
            visible: !root.swapping

            Component.onCompleted: {
                opacity = 1
                root.dockShown = true
            }

            Behavior on x { enabled: !root.swapping; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !root.swapping; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Keys.onEscapePressed: root.escPressed()

            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 13000
            }

            Grid {
                id: dockCol

                x: root.dockPos === "left" ? 20 : 8
                y: 8
                columns: root.horiz ? Math.max(1, root.allItems.length) : 1
                spacing: 6

                Repeater {
                    model: root.allItems

                    Item {
                        id: slot

                        required property int index
                        required property var modelData

                        readonly property bool isSep: modelData.sep === true

                        width: root.horiz ? (isSep ? 8 : 40) : 40
                        height: root.horiz ? 40 : (isSep ? 8 : 40)

                        Rectangle {
                            visible: slot.isSep
                            anchors.centerIn: parent
                            width: root.horiz ? 1 : 24
                            height: root.horiz ? 24 : 1
                            color: root.lineColor
                        }

                        DockBtn {
                            visible: !slot.isSep
                            anchors.fill: parent
                            it: slot.modelData
                            on: !slot.isSep && root.isOn(slot.modelData)
                            hover: root.hov === slot.index
                            lifted: root.dragging && root.pressIdx === slot.index
                        }
                    }
                }
            }

            MouseArea {
                x: dockCol.x
                y: dockCol.y
                width: dockCol.width
                height: dockCol.height
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : (root.hov >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor)

                onPositionChanged: m => {
                    if (pressed)
                        root.dragMove(m.x, m.y, root.railTarget(root.horiz ? m.x : m.y))
                    else
                        root.hov = root.railAt(root.horiz ? m.x : m.y)
                }
                onExited: if (!pressed) root.hov = -1
                onPressed: m => root.dragStart(root.railAt(root.horiz ? m.x : m.y), m.x, m.y, m.button)
                onReleased: m => root.dragEnd(root.allItems, root.railAt(root.horiz ? m.x : m.y), m.button)
            }
        }
    }

    PanelWindow {
        id: popWin

        visible: root.popupMode
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
        }

        margins {
            top: 30
            left: root.popLeft
        }

        implicitWidth: 324
        implicitHeight: popCard.height + 16

        WlrLayershell.namespace: "doiz-dock-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: popCard

            x: 6
            y: 0
            width: 312
            height: 34 + pgrid.implicitHeight + 14
            radius: 12
            color: root.panelColor
            focus: true
            opacity: 0

            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 13000
            }

            border.width: 1
            border.color: root.tint(root.accentColor, 0.45)

            Component.onCompleted: {
                opacity = 1
                y = 10
            }

            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Keys.onEscapePressed: root.escPressed()

            Text {
                x: 14
                y: 10
                text: "Apps"
                color: root.accentColor
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Grid {
                id: pgrid

                x: 14
                y: 34
                columns: 4
                spacing: 4

                Repeater {
                    model: root.tiles

                    DockBtn {
                        required property int index
                        required property var modelData

                        compact: false
                        it: modelData
                        on: root.isOn(modelData)
                        hover: root.hov === index
                        lifted: root.dragging && root.pressIdx === index
                    }
                }
            }

            MouseArea {
                x: pgrid.x
                y: pgrid.y
                width: pgrid.implicitWidth
                height: pgrid.implicitHeight
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.dragging ? Qt.ClosedHandCursor : (root.hov >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor)

                onPositionChanged: m => {
                    if (pressed)
                        root.dragMove(m.x, m.y, root.gridTarget(m.x, m.y))
                    else
                        root.hov = root.gridAt(m.x, m.y)
                }
                onExited: if (!pressed) root.hov = -1
                onPressed: m => root.dragStart(root.gridAt(m.x, m.y), m.x, m.y, m.button)
                onReleased: m => root.dragEnd(root.tiles, root.gridAt(m.x, m.y), m.button)
            }
        }
    }

    PanelWindow {
        id: appWin

        visible: root.appMode
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WlrLayershell.namespace: "doiz-dock-apps"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible) {
                root.pickQuery = ""
                appSearch.text = ""
                appSearch.forceActiveFocus()
            }
        }

        Rectangle {
            id: appBack

            readonly property int cols: Math.max(3, Math.min(8, Math.floor((width - 160) / 120)))

            anchors.fill: parent
            color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.9)
            focus: true
            opacity: 0

            Component.onCompleted: opacity = 1

            Behavior on opacity { NumberAnimation { duration: 160 } }

            Keys.onEscapePressed: root.closePopup()

            MouseArea {
                anchors.fill: parent
                onClicked: root.closePopup()
            }

            Rectangle {
                id: searchBox

                x: (parent.width - width) / 2
                y: 64
                width: 420
                height: 38
                radius: 8
                color: root.cardColor
                border.width: 1
                border.color: root.tint(root.accentColor, 0.35 + 0.3 * root.pulse)

                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    color: root.accentColor
                    font.family: root.mono
                    font.pixelSize: 13
                }

                TextInput {
                    id: appSearch

                    anchors.fill: parent
                    anchors.leftMargin: 36
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.titleColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.inkColor
                    font.family: root.mono
                    font.pixelSize: 13
                    clip: true
                    onTextChanged: root.pickQuery = text
                    Keys.onEscapePressed: root.closePopup()
                    Keys.onReturnPressed: {
                        if (root.pickList.length > 0)
                            root.launchKey(root.pickList[0].key)
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 36
                    verticalAlignment: Text.AlignVCenter
                    visible: appSearch.text === ""
                    text: "Search apps & functions..."
                    color: root.mutedColor
                    font.family: root.mono
                    font.pixelSize: 13
                }
            }

            Text {
                x: (parent.width - width) / 2
                y: 110
                text: "Click to open  -  right-click to pin / unpin on the dash"
                color: root.mutedColor
                font.family: root.mono
                font.pixelSize: 9
            }

            GridView {
                id: agrid

                x: (parent.width - width) / 2
                y: 140
                width: appBack.cols * 120
                height: parent.height - 140 - 120
                cellWidth: 120
                cellHeight: 112
                clip: true
                model: root.pickList

                delegate: Item {
                    required property var modelData

                    readonly property bool pinned: root.layout.indexOf(modelData.key) >= 0

                    width: 120
                    height: 112

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 8
                        color: am.containsMouse ? root.tint(root.accentColor, 0.16) : "transparent"
                    }

                    Rectangle {
                        visible: modelData.isFn
                        x: 32
                        y: 12
                        width: 56
                        height: 56
                        radius: 8
                        color: root.cardColor
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.3)

                        Text {
                            anchors.centerIn: parent
                            text: modelData.g
                            color: root.accentColor
                            font.family: root.mono
                            font.pixelSize: 22
                        }
                    }

                    IconImage {
                        visible: !modelData.isFn
                        x: 32
                        y: 12
                        width: 56
                        height: 56
                        source: modelData.isFn ? "" : Quickshell.iconPath(modelData.icon, "application-x-executable")
                    }

                    Rectangle {
                        visible: pinned
                        x: 86
                        y: 10
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.accentColor
                    }

                    Text {
                        x: 6
                        y: 76
                        width: 108
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData.name
                        color: am.containsMouse ? root.titleColor : root.textColor
                        font.family: root.mono
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: am

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                root.togglePin(modelData.key)
                            else
                                root.launchKey(modelData.key)
                        }
                    }
                }
            }

            Rectangle {
                id: dash

                x: (parent.width - width) / 2
                y: parent.height - height - 16
                width: dashRow.width + 24
                height: 68
                radius: 12
                color: root.panelColor
                border.width: 1
                border.color: root.tint(root.accentColor, 0.45)

                GradBorder {
                    rr: 12
                    c1: root.accentColor
                    c2: root.toneB
                    c3: root.accentColor
                    c4: root.toneB
                    cycle: 13000
                }

                Row {
                    id: dashRow

                    x: 12
                    y: 14
                    spacing: 6

                    Repeater {
                        model: root.dashItems

                        Item {
                            id: dslot

                            required property var modelData

                            width: 40
                            height: 40

                            DockBtn {
                                anchors.fill: parent
                                it: dslot.modelData
                                on: root.isOn(dslot.modelData)
                                hover: dma.containsMouse
                            }

                            MouseArea {
                                id: dma

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton)
                                        root.secondary(dslot.modelData)
                                    else
                                        root.activate(dslot.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: pickerWin

        visible: root.pickerOpen && !root.closing
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            left: root.popupMode || root.placePos === "left"
            right: !root.popupMode && root.placePos === "right"
            bottom: !root.popupMode && root.placePos === "bottom"
            top: root.popupMode
        }

        margins {
            left: root.popupMode ? root.popLeft + 2 : (root.placePos === "left" ? 80 : 0)
            right: root.placePos === "right" ? 80 : 0
            bottom: root.placePos === "bottom" ? root.placeGap : 0
            top: root.popupMode ? root.belowTop : 0
        }

        implicitWidth: 316
        implicitHeight: 336

        WlrLayershell.namespace: "doiz-dock-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible) {
                root.pickQuery = ""
                searchInput.text = ""
                searchInput.forceActiveFocus()
            }
        }

        Rectangle {
            x: 4
            y: 4
            width: 308
            height: 328
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
            border.color: root.tint(root.accentColor, 0.45)

            Text {
                x: 14
                y: 10
                text: "\uf067  Add app / function"
                color: root.accentColor
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Rectangle {
                x: 14
                y: 34
                width: parent.width - 28
                height: 28
                radius: 3
                color: root.cardColor
                border.width: 1
                border.color: root.tint(root.accentColor, 0.3)

                TextInput {
                    id: searchInput

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.titleColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.inkColor
                    font.family: root.mono
                    font.pixelSize: 11
                    clip: true
                    onTextChanged: root.pickQuery = text
                    Keys.onEscapePressed: root.pickerOpen = false
                    Keys.onReturnPressed: {
                        if (root.pickList.length > 0) {
                            root.addKey(root.pickList[0].key)
                            root.pickerOpen = false
                        }
                    }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    visible: searchInput.text === ""
                    text: "Search apps & functions..."
                    color: root.mutedColor
                    font.family: root.mono
                    font.pixelSize: 11
                }
            }

            ListView {
                x: 14
                y: 70
                width: parent.width - 28
                height: parent.height - 84
                clip: true
                spacing: 2
                model: root.pickList

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool taken: root.layout.indexOf(modelData.key) >= 0

                    width: ListView.view.width
                    height: 34
                    radius: 3
                    color: rowMa.containsMouse ? root.tint(root.accentColor, 0.18) : "transparent"

                    Text {
                        x: 6
                        width: 22
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: modelData.isFn
                        text: modelData.g
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 14
                    }

                    IconImage {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        visible: !modelData.isFn
                        source: modelData.isFn ? "" : Quickshell.iconPath(modelData.icon, "application-x-executable")
                    }

                    Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36 - 28
                        elide: Text.ElideRight
                        text: modelData.name
                        color: taken ? root.mutedColor : root.titleColor
                        font.family: root.mono
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: taken
                        text: "\uf00c"
                        color: root.accentColor
                        font.family: root.mono
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: rowMa

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (taken) {
                                root.removeKey(modelData.key)
                            } else {
                                root.addKey(modelData.key)
                                root.pickerOpen = false
                            }
                        }
                    }
                }
            }
        }
    }

    PanelWindow {
        id: notesWin

        visible: root.notesShown || notesCard.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            left: root.popupMode || root.placePos === "left"
            right: !root.popupMode && root.placePos === "right"
            bottom: !root.popupMode && root.placePos === "bottom"
            top: root.popupMode
        }

        margins {
            left: root.popupMode ? root.popLeft + 2 : (root.placePos === "left" ? 80 : 0)
            right: root.placePos === "right" ? 80 : 0
            bottom: root.placePos === "bottom" ? root.placeGap : 0
            top: root.popupMode ? root.belowTop : 0
        }

        implicitWidth: 316
        implicitHeight: 246

        WlrLayershell.namespace: "doiz-notes"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: notesCard

            x: 4
            y: root.notesShown ? 10 : 0
            width: 308
            height: 228
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
            border.color: root.tint(root.accentColor, 0.45)
            opacity: root.notesShown ? 1 : 0

            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Text {
                x: 14
                y: 10
                text: "\uf040  Notes"
                color: root.accentColor
                font.family: root.mono
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            Flickable {
                id: flick

                x: 14
                y: 34
                width: parent.width - 28
                height: parent.height - 48
                contentWidth: width
                contentHeight: editor.paintedHeight + 8
                clip: true

                TextEdit {
                    id: editor

                    width: flick.width
                    height: Math.max(flick.height, paintedHeight + 8)
                    wrapMode: TextEdit.Wrap
                    color: root.titleColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.inkColor
                    font.family: root.mono
                    font.pixelSize: 12
                    focus: root.notesOpen
                    onTextChanged: if (root.notesReady) saveTimer.restart()
                    Keys.onEscapePressed: root.escPressed()

                    onCursorRectangleChanged: {
                        var r = cursorRectangle
                        if (r.y < flick.contentY)
                            flick.contentY = r.y
                        else if (r.y + r.height > flick.contentY + flick.height)
                            flick.contentY = r.y + r.height - flick.height
                    }
                }
            }
        }
    }
}
