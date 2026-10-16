import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel

ShellRoot {
    id: root

    readonly property string shot: Quickshell.env("DOIZ_SHOT") || ""
    readonly property string saveDir: Quickshell.env("DOIZ_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots")
    readonly property string cfgDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    property string savePath: saveDir
    readonly property string savePathFile: cfgDir + "/doiz/screenshot-dir"

    property color bgColor: "#12141f"
    property color cardColor: "#1f2231"
    property color accentColor: "#cba6f7"
    property color titleColor: "#ebeffa"
    property color textColor: "#cdd3e6"

    property string tool: "pen"
    property color penColor: "#f38ba8"
    property real penWidth: 4
    readonly property real minWidth: 1
    readonly property real maxWidth: 60

    readonly property var brushes: [
        { id: "pen",    label: "Pen" },
        { id: "marker", label: "Marker" },
        { id: "hl",     label: "Light" },
        { id: "neon",   label: "Neon" },
        { id: "spray",  label: "Spray" },
        { id: "eraser", label: "Erase" }
    ]
    readonly property var shapes: [
        { id: "line",  label: "Line" },
        { id: "rect",  label: "Rect" },
        { id: "oval",  label: "Oval" },
        { id: "arrow", label: "Arrow" }
    ]
    readonly property var freehand: ["pen", "marker", "hl", "neon", "spray", "eraser"]

    property var strokes: []
    property var live: null
    property bool busy: false
    property bool closing: false

    readonly property var palette: ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa",
                                    "#b4befe", "#cba6f7", "#f5c2e7", "#eba0ac", "#ffffff", "#000000"]

    property var quickColors: ["#f38ba8", "#f9e2af", "#89b4fa"]
    property bool paletteOpen: false
    property bool browseOpen: false
    property bool brushOpen: false
    property string brush: "pen"
    property real brushMenuX: 0

    function brushLabel() {
        for (var i = 0; i < root.brushes.length; i++) {
            if (root.brushes[i].id === root.brush)
                return root.brushes[i].label
        }
        return "Brush"
    }
    property bool browseHidden: false
    property string browseDir: ""

    function parentOf(d) {
        var i = d.lastIndexOf("/")
        return i <= 0 ? "/" : d.substring(0, i)
    }

    function dirUrl(d) {
        return "file://" + d.split("/").map(encodeURIComponent).join("/")
    }

    function openBrowse() {
        root.paletteOpen = false
        root.brushOpen = false
        root.browseDir = root.normalizeDir(root.savePath)
        root.browseOpen = true
    }

    function chooseBrowse() {
        root.savePath = root.browseDir
        root.browseOpen = false
    }

    function pushQuick(c) {
        var hex = String(Qt.color(c))
        var next = [hex]
        for (var i = 0; i < root.quickColors.length && next.length < 3; i++) {
            if (!Qt.colorEqual(root.quickColors[i], hex))
                next.push(root.quickColors[i])
        }
        root.quickColors = next
    }

    FileView {
        id: savePathStore
        path: root.savePathFile
        blockLoading: true
        onLoaded: {
            var v = text().trim()
            if (v !== "")
                root.savePath = v
        }
    }

    FileView {
        id: themeFile
        path: root.cfgDir + "/theme/theme.conf"
        blockLoading: true
        onLoaded: root.applyTheme(text())
    }

    function applyTheme(data) {
        var inColors = false
        var c = {}
        var lines = data.split(/\r?\n/)

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line || line.indexOf("#") === 0)
                continue

            if (line.indexOf("[") === 0) {
                inColors = line === "[colors]"
                continue
            }

            var eq = line.indexOf("=")

            if (!inColors || eq === -1)
                continue

            var v = line.substring(eq + 1).trim().split(" ")[0]

            if (/^#[0-9a-fA-F]{6,8}$/.test(v))
                c[line.substring(0, eq).trim()] = v
        }

        if (c["background"]) root.bgColor = c["background"]
        if (c["surface"]) root.cardColor = c["surface"]
        if (c["accent"]) root.accentColor = c["accent"]
        if (c["foreground"]) root.titleColor = c["foreground"]
        if (c["subtext"]) root.textColor = c["subtext"]
    }

    function undo() {
        if (root.strokes.length > 0)
            root.strokes = root.strokes.slice(0, root.strokes.length - 1)
    }

    function clearAll() {
        root.strokes = []
    }

    function normalizeDir(raw) {
        var d = String(raw).trim()

        if (d === "")
            return root.saveDir

        if (d === "~")
            d = Quickshell.env("HOME")
        else if (d.indexOf("~/") === 0)
            d = Quickshell.env("HOME") + d.substring(1)

        while (d.length > 1 && d.charAt(d.length - 1) === "/")
            d = d.substring(0, d.length - 1)

        return d
    }

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")
    }

    function finish(script, args) {
        root.closing = true
        Quickshell.execDetached(["sh", "-c", script, "doiz"].concat(args))
        quitTimer.start()
    }

    function discard() {
        root.finish("rm -f \"$1\"", [root.shot])
    }

    function render(done) {
        if (root.strokes.length === 0) {
            done(root.shot)
            return
        }

        var out = root.shot + ".annotated.png"

        exportItem.grabToImage(function(res) {
            res.saveToFile(out)
            done(out)
        }, Qt.size(photo.implicitWidth, photo.implicitHeight))
    }

    function save() {
        if (root.busy)
            return

        root.busy = true

        var dir = root.normalizeDir(root.savePath)
        var dest = dir + "/area-" + root.stamp() + ".png"

        root.render(function(src) {
            root.finish(
                "if mkdir -p \"$(dirname \"$2\")\" \"$(dirname \"$4\")\" && mv -f \"$1\" \"$2\"; then " +
                "printf '%s\\n' \"$5\" > \"$4.tmp\" && mv -f \"$4.tmp\" \"$4\"; out=$2; " +
                "else mkdir -p \"$(dirname \"$6\")\" && mv -f \"$1\" \"$6\" && out=$6 && " +
                "notify-send -a DoiZ -u critical 'Save folder not writable' 'Saved to the default folder instead'; fi; " +
                "rm -f \"$3\"; [ -n \"$out\" ] && notify-send -a DoiZ 'Screenshot saved' \"$out\"",
                [src, dest, root.shot, root.savePathFile, dir, root.saveDir + "/area-" + root.stamp() + ".png"]
            )
        })
    }

    function copy() {
        if (root.busy)
            return

        root.busy = true

        root.render(function(src) {
            root.finish(
                "wl-copy --type image/png < \"$1\"; rm -f \"$1\" \"$2\"; notify-send -a DoiZ 'Screenshot copied' 'Image is in the clipboard'",
                [src, root.shot]
            )
        })
    }

    IpcHandler {
        target: "screenshot"

        function discard(): void {
            if (!root.closing)
                root.discard()
        }
    }

    Timer {
        id: quitTimer
        interval: 400
        onTriggered: Qt.quit()
    }

    PanelWindow {
        id: win

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.namespace: "doiz_screenshot"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: root.closing ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.browseOpen)
                    root.browseOpen = false
                else if (root.brushOpen)
                    root.brushOpen = false
                else if (root.paletteOpen)
                    root.paletteOpen = false
                else if (root.strokes.length === 0 && !root.busy)
                    root.discard()
            }
        }

        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (root.browseOpen)
                    root.browseOpen = false
                else if (root.brushOpen)
                    root.brushOpen = false
                else if (root.paletteOpen)
                    root.paletteOpen = false
                else if (pathInput.activeFocus)
                    stage.forceActiveFocus()
                else
                    root.discard()
            }
        }

        Shortcut {
            sequence: "Ctrl+Z"
            enabled: !pathInput.activeFocus
            onActivated: root.undo()
        }

        Shortcut {
            sequence: "Ctrl+C"
            enabled: !pathInput.activeFocus
            onActivated: root.copy()
        }

        Shortcut {
            sequence: "Ctrl+S"
            onActivated: root.save()
        }

        Item {
            id: exportItem

            x: -photo.implicitWidth - 200
            y: 0
            width: photo.implicitWidth
            height: photo.implicitHeight

            Image {
                anchors.fill: parent
                source: photo.source
                asynchronous: false
                cache: false
            }

            Annot {
                anchors.fill: parent
                nw: photo.implicitWidth
                strokes: root.strokes
            }
        }

        Rectangle {
            id: card

            readonly property real maxW: win.width * 0.8
            readonly property real maxH: win.height * 0.72
            readonly property real nw: Math.max(1, photo.implicitWidth)
            readonly property real nh: Math.max(1, photo.implicitHeight)
            readonly property real fit: Math.min(1, maxW / nw, maxH / nh)
            readonly property real viewW: Math.round(nw * fit)
            readonly property real viewH: Math.round(nh * fit)

            anchors.centerIn: parent

            opacity: root.closing ? 0 : 1
            scale: root.closing ? 0.97 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
            }

            width: Math.max(viewW + 32, 700)
            height: viewH + 32 + toolbar.height + pathRow.height + 10 + footer.height + 24
            radius: 14
            color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

            ColumnLayout {
                id: toolbar

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                height: 68
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 5

                    Btn {
                        id: brushBtn

                        label: root.brushLabel() + "  \u25be"
                        pad: 16
                        active: root.brushOpen || root.freehand.indexOf(root.tool) >= 0
                        tone: root.accentColor
                        fg: root.titleColor
                        onClicked: {
                            if (root.brushOpen) {
                                root.brushOpen = false
                                return
                            }

                            root.paletteOpen = false
                            root.brushMenuX = brushBtn.mapToItem(card, 0, 0).x
                            root.brushOpen = true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 18
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                    }

                    Repeater {
                        model: root.shapes

                        delegate: Btn {
                            required property var modelData

                            label: modelData.label
                            pad: 16
                            active: root.tool === modelData.id
                            tone: root.accentColor
                            fg: root.titleColor
                            onClicked: root.tool = modelData.id
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 6

                    Repeater {
                        model: root.quickColors

                        delegate: Rectangle {
                            required property string modelData

                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: modelData
                            border.width: Qt.colorEqual(root.penColor, modelData) ? 2 : 1
                            border.color: Qt.colorEqual(root.penColor, modelData)
                                ? root.titleColor
                                : Qt.rgba(1, 1, 1, 0.25)

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.penColor = parent.modelData
                            }
                        }
                    }

                    Rectangle {
                        id: moreBtn

                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 11
                        border.width: root.paletteOpen ? 2 : 1
                        border.color: root.paletteOpen ? root.titleColor : Qt.rgba(1, 1, 1, 0.25)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#f38ba8" }
                            GradientStop { position: 0.33; color: "#f9e2af" }
                            GradientStop { position: 0.66; color: "#a6e3a1" }
                            GradientStop { position: 1.0; color: "#89b4fa" }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.penColor
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.6)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.paletteOpen)
                                    picker.openAt(moreBtn.mapToItem(card, 0, moreBtn.height).x)
                                else
                                    root.paletteOpen = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 18
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
                    }

                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.max(2, Math.min(26, root.penWidth))
                            height: width
                            radius: width / 2
                            color: root.penColor
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }

                    Item {
                        id: sizeSlider

                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 26

                        readonly property real frac: (root.penWidth - root.minWidth) / (root.maxWidth - root.minWidth)

                        function setFrom(x) {
                            var f = Math.max(0, Math.min(1, x / width))
                            root.penWidth = Math.round(root.minWidth + f * (root.maxWidth - root.minWidth))
                        }

                        Rectangle {
                            id: track

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)

                            Rectangle {
                                width: sizeSlider.frac * track.width
                                height: parent.height
                                radius: 2
                                color: root.accentColor
                            }
                        }

                        Rectangle {
                            x: sizeSlider.frac * (sizeSlider.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: 7
                            color: sizeMouse.pressed ? Qt.lighter(root.accentColor, 1.15) : root.accentColor
                            border.width: 2
                            border.color: root.titleColor
                        }

                        MouseArea {
                            id: sizeMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: m => sizeSlider.setFrom(m.x)
                            onPositionChanged: m => { if (pressed) sizeSlider.setFrom(m.x) }
                            onWheel: w => {
                                var d = w.angleDelta.y > 0 ? 1 : -1
                                root.penWidth = Math.max(root.minWidth, Math.min(root.maxWidth, root.penWidth + d))
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 34
                        text: Math.round(root.penWidth) + " px"
                        color: root.textColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Btn {
                        label: "Undo"
                        tone: root.accentColor
                        fg: root.titleColor
                        onClicked: root.undo()
                    }

                    Btn {
                        label: "Clear"
                        tone: root.accentColor
                        fg: root.titleColor
                        onClicked: root.clearAll()
                    }
                }
            }

            MouseArea {
                x: -card.x
                y: -card.y
                width: win.width
                height: win.height
                z: 50
                visible: root.paletteOpen || root.brushOpen
                onClicked: {
                    root.paletteOpen = false
                    root.brushOpen = false
                }
            }

            Rectangle {
                id: brushMenu

                x: root.brushMenuX
                y: toolbar.y + 30 + 6
                z: 51
                width: 132
                height: brushCol.implicitHeight + 16
                radius: 12
                color: root.cardColor
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                opacity: root.brushOpen ? 1 : 0
                scale: root.brushOpen ? 1 : 0.92
                transformOrigin: Item.TopLeft
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: brushCol

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Repeater {
                        model: root.brushes

                        delegate: Btn {
                            required property var modelData

                            Layout.fillWidth: true
                            label: modelData.label
                            active: root.tool === modelData.id
                            tone: root.accentColor
                            fg: root.titleColor
                            onClicked: {
                                root.brush = modelData.id
                                root.tool = modelData.id
                                root.brushOpen = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: picker

                property real hue: 0
                property real sat: 1
                property real val: 1

                function openAt(px) {
                    var c = Qt.color(root.penColor)
                    hue = c.hsvHue < 0 ? 0 : c.hsvHue
                    sat = c.hsvSaturation
                    val = c.hsvValue
                    x = Math.max(8, Math.min(px, card.width - width - 8))
                    root.brushOpen = false
                    root.paletteOpen = true
                }

                function apply() {
                    root.penColor = Qt.hsva(hue, sat, val, 1)
                }

                y: toolbar.y + toolbar.height + 6
                z: 51

                opacity: root.paletteOpen ? 1 : 0
                scale: root.paletteOpen ? 1 : 0.92
                transformOrigin: Item.TopLeft
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                width: 204
                height: col.implicitHeight + 24
                radius: 12
                color: root.cardColor
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: col

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    GridLayout {
                        columns: 6
                        rowSpacing: 6
                        columnSpacing: 6

                        Repeater {
                            model: root.palette

                            delegate: Rectangle {
                                required property string modelData

                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 12
                                color: modelData
                                border.width: Qt.colorEqual(root.penColor, modelData) ? 2 : 1
                                border.color: Qt.colorEqual(root.penColor, modelData)
                                    ? root.titleColor
                                    : Qt.rgba(1, 1, 1, 0.25)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.penColor = parent.modelData
                                        root.pushQuick(parent.modelData)
                                        root.paletteOpen = false
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: svBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        radius: 6
                        clip: true
                        color: Qt.hsva(picker.hue, 1, 1, 1)

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#ffffffff" }
                                GradientStop { position: 1.0; color: "#00ffffff" }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#00000000" }
                                GradientStop { position: 1.0; color: "#ff000000" }
                            }
                        }

                        Rectangle {
                            x: picker.sat * svBox.width - width / 2
                            y: (1 - picker.val) * svBox.height - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: "transparent"
                            border.width: 2
                            border.color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor
                            function pick(m) {
                                picker.sat = Math.max(0, Math.min(1, m.x / width))
                                picker.val = 1 - Math.max(0, Math.min(1, m.y / height))
                                picker.apply()
                            }
                            onPressed: m => pick(m)
                            onPositionChanged: m => { if (pressed) pick(m) }
                            onReleased: root.pushQuick(root.penColor)
                        }
                    }

                    Rectangle {
                        id: hueBar

                        Layout.fillWidth: true
                        Layout.preferredHeight: 12
                        radius: 6
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#ff0000" }
                            GradientStop { position: 0.17; color: "#ffff00" }
                            GradientStop { position: 0.33; color: "#00ff00" }
                            GradientStop { position: 0.5; color: "#00ffff" }
                            GradientStop { position: 0.67; color: "#0000ff" }
                            GradientStop { position: 0.83; color: "#ff00ff" }
                            GradientStop { position: 1.0; color: "#ff0000" }
                        }

                        Rectangle {
                            x: picker.hue * (hueBar.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 16
                            radius: 4
                            color: "#ffffff"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.4)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function pick(m) {
                                picker.hue = Math.max(0, Math.min(1, m.x / width))
                                picker.apply()
                            }
                            onPressed: m => pick(m)
                            onPositionChanged: m => { if (pressed) pick(m) }
                            onReleased: root.pushQuick(root.penColor)
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: root.penColor
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                        }

                        Text {
                            text: String(root.penColor).toUpperCase()
                            color: root.textColor
                            font.pixelSize: 12
                            font.family: "monospace"
                        }
                    }
                }
            }

            Rectangle {
                id: stage

                anchors.top: toolbar.bottom
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter

                width: card.viewW
                height: card.viewH
                color: root.cardColor
                radius: 4
                clip: true

                Image {
                    id: photo

                    anchors.fill: parent
                    source: root.shot !== "" ? "file://" + root.shot : ""
                    asynchronous: false
                    cache: false
                }

                Annot {
                    anchors.fill: parent
                    nw: card.nw
                    strokes: root.strokes
                    live: root.live
                }

                MouseArea {
                    id: draw

                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton

                    function pt(m) {
                        return [
                            Math.max(0, Math.min(card.nw, m.x / card.fit)),
                            Math.max(0, Math.min(card.nh, m.y / card.fit))
                        ]
                    }

                    onPressed: function(m) {
                        root.live = {
                            tool: root.tool,
                            color: String(root.penColor),
                            w: root.penWidth / card.fit,
                            pts: [draw.pt(m)],
                            seed: Math.floor(Math.random() * 1000000000)
                        }
                    }

                    onPositionChanged: function(m) {
                        if (!root.live)
                            return

                        var s = root.live
                        var p = draw.pt(m)

                        if (root.freehand.indexOf(s.tool) >= 0)
                            s.pts = s.pts.concat([p])
                        else
                            s.pts = [s.pts[0], p]

                        root.live = {
                            tool: s.tool,
                            color: s.color,
                            w: s.w,
                            pts: s.pts,
                            seed: s.seed
                        }
                    }

                    onReleased: function(m) {
                        if (!root.live)
                            return

                        var s = root.live

                        root.live = null
                        root.strokes = root.strokes.concat([s])
                    }
                }
            }

            RowLayout {
                id: pathRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 10
                height: 30
                spacing: 8

                Text {
                    text: "Save to"
                    color: root.textColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, pathInput.activeFocus ? 0.14 : 0.07)
                    border.width: 1
                    border.color: pathInput.activeFocus
                        ? root.accentColor
                        : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)

                    TextInput {
                        id: pathInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        color: root.titleColor
                        selectionColor: root.accentColor
                        selectedTextColor: root.bgColor
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11

                        text: root.savePath
                        onTextEdited: root.savePath = text
                        onAccepted: stage.forceActiveFocus()
                    }
                }

                Btn {
                    label: "Browse"
                    tone: root.accentColor
                    fg: root.titleColor
                    active: root.browseOpen
                    onClicked: root.openBrowse()
                }

                Btn {
                    label: "Reset"
                    tone: root.accentColor
                    fg: root.titleColor
                    onClicked: root.savePath = root.saveDir
                }
            }

            MouseArea {
                x: -card.x
                y: -card.y
                width: win.width
                height: win.height
                z: 60
                visible: root.browseOpen
                onClicked: root.browseOpen = false
            }

            Rectangle {
                id: browser

                anchors.centerIn: parent
                z: 61
                width: 520
                height: 380
                radius: 12
                color: root.cardColor
                border.width: 1
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                opacity: root.browseOpen ? 1 : 0
                scale: root.browseOpen ? 1 : 0.95
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                }

                FolderListModel {
                    id: dirModel

                    folder: root.dirUrl(root.browseDir)
                    showFiles: false
                    showDirs: true
                    showDotAndDotDot: false
                    showHidden: root.browseHidden
                    sortField: FolderListModel.Name
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Btn {
                            label: "\u2191 Up"
                            tone: root.accentColor
                            fg: root.titleColor
                            onClicked: root.browseDir = root.parentOf(root.browseDir)
                        }

                        Btn {
                            label: "Home"
                            tone: root.accentColor
                            fg: root.titleColor
                            onClicked: root.browseDir = Quickshell.env("HOME")
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 8
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideLeft
                                text: root.browseDir
                                color: root.titleColor
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.6)
                        border.width: 1
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                        clip: true

                        ListView {
                            id: dirList

                            anchors.fill: parent
                            anchors.margins: 4
                            model: dirModel
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: dirRow

                                required property string fileName
                                required property string filePath

                                width: dirList.width
                                height: 30
                                radius: 6
                                color: rowArea.containsMouse
                                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                                    : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    spacing: 10

                                    Text {
                                        text: "\uf07b"
                                        color: root.accentColor
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: dirRow.fileName
                                        color: root.titleColor
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: rowArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.browseDir = dirRow.filePath
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: dirList.count === 0
                            text: dirModel.status === FolderListModel.Null ? "Folder does not exist yet" : "No subfolders"
                            color: root.textColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Btn {
                            label: "Hidden"
                            tone: root.accentColor
                            fg: root.titleColor
                            active: root.browseHidden
                            onClicked: root.browseHidden = !root.browseHidden
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Btn {
                            label: "Cancel"
                            tone: root.accentColor
                            fg: root.titleColor
                            onClicked: root.browseOpen = false
                        }

                        Btn {
                            label: "Select"
                            primary: true
                            tone: root.accentColor
                            onClicked: root.chooseBrowse()
                        }
                    }
                }
            }

            RowLayout {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                height: 34
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: card.nw + " × " + card.nh + "   ·   Esc / Super+Q to discard"
                    color: root.textColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

                Btn {
                    label: "Discard"
                    tone: root.accentColor
                    fg: root.titleColor
                    implicitHeight: 34
                    onClicked: root.discard()
                }

                Btn {
                    label: "Copy"
                    tone: root.accentColor
                    fg: root.titleColor
                    implicitHeight: 34
                    onClicked: root.copy()
                }

                Btn {
                    label: "Save"
                    primary: true
                    tone: root.accentColor
                    implicitHeight: 34
                    onClicked: root.save()
                }
            }
        }
    }
}
