import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

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

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            if (root.shown) {
                root.closePopup()
                return
            }

            root.shown = true
            root.refreshPopup()
        }

        function show(): void {
            root.shown = true
            root.refreshPopup()
        }

        function hide(): void {
            root.closePopup()
        }
    }

    property var allItems: []
    property string query: ""
    property int selIndex: 0
    property bool confirmClear: false
    property int imageRev: 0
    property var imageIds: []
    property int maxItems: 100
    property string tab: "text"
    property bool tabChosen: false
    property bool closingNow: false
    property int slideDir: 1
    property int imageCount: 0
    property int textCount: 0
    property int maxImages: 24

    property string cacheDir:
        (
            Quickshell.env("XDG_RUNTIME_DIR") ||
            "/tmp"
        ) + "/doiz-clipboard"

    property string themeFile:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/theme/theme.conf"

    property bool themeReady: false
    property bool listChecked: false

    property bool ready:
        root.themeReady &&
        root.listChecked

    property color basePanelColor
    property color baseCardColor
    property color baseTrackColor
    property color lineColor
    property color titleColor
    property color textColor
    property color mutedColor
    property color accentColor
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color accentAltColor
    property color connectedColor: "#81AA99"
    property color infoColor: "#8f8f8f"
    property color dangerColor: "#B2729E"
    property string fontName: "JetBrainsMono Nerd Font"

    Behavior on panelColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on cardColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on trackColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on lineColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on titleColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on textColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on mutedColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on accentColor { enabled: root.ready; ColorAnimation { duration: 400 } }
    Behavior on accentAltColor { enabled: root.ready; ColorAnimation { duration: 400 } }

    property bool available:
        root.allItems.length > 0

    property color stateColor:
        root.available
        ? root.accentColor
        : root.mutedColor

    property color iconColor:
        root.available
        ? root.accentAltColor
        : root.mutedColor

    property string statusText:
        !root.listChecked
        ? "Loading"
        : !root.available
          ? "Empty"
          : root.query.trim() !== ""
            ? itemModel.count + " matches"
            : "History"

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function hexColor(hex, alpha) {
        return Qt.rgba(
            parseInt(hex.substring(1, 3), 16) / 255,
            parseInt(hex.substring(3, 5), 16) / 255,
            parseInt(hex.substring(5, 7), 16) / 255,
            alpha
        )
    }

    function loadTheme() {
        themeProcess.running = false
        themeProcess.running = true
    }

    function loadList() {
        listProcess.running = false
        listProcess.running = true
    }

    function parseTheme(data) {
        var lines = data.split("\n")
        var section = ""
        var colors = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line)
                continue

            if (line.charAt(0) === "[") {
                section = line.substring(1, line.length - 1)
                continue
            }

            if (section !== "colors")
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
                continue

            colors[line.substring(0, separator).trim()] =
                line.substring(separator + 1).trim()
        }

        if (colors["background"])
            root.basePanelColor = root.hexColor(colors["background"], 0.95)

        if (colors["surface"])
            root.baseCardColor = root.hexColor(colors["surface"], 0.62)

        if (colors["surface_alt"])
            root.baseTrackColor = root.hexColor(colors["surface_alt"], 0.35)

        if (colors["foreground"])
            root.titleColor = colors["foreground"]

        if (colors["subtext"])
            root.textColor = colors["subtext"]

        if (colors["muted"])
            root.mutedColor = colors["muted"]

        if (colors["green"])
            root.connectedColor = colors["green"]

        if (colors["cyan"])
            root.infoColor = colors["cyan"]

        if (colors["red"])
            root.dangerColor = colors["red"]

        if (colors["accent"]) {
            root.accentColor = (colors["accent_alt"] || colors["accent"])
            root.lineColor = root.hexColor(colors["accent"], 0.25)
        }

        if (colors["accent_alt"])
            root.accentAltColor = colors["accent_alt"]

        root.themeReady = true
    }

    function parseList(data) {
        var lines = data.split("\n")
        var items = []
        var ids = []
        var binary =
            /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var tab = line.indexOf("\t")

            if (tab <= 0)
                continue

            var id = line.substring(0, tab)
            var content = line.substring(tab + 1).trim()
            var m = binary.exec(content)

            if (m) {
                items.push({
                    clipId: id,
                    text: "Image " + m[3],
                    meta: m[2].toUpperCase() + " · " + m[1],
                    isImage: true
                })

                if (ids.length < root.maxImages)
                    ids.push(id)
            } else {
                items.push({
                    clipId: id,
                    text: content.replace(/\s+/g, " "),
                    meta: "Text · " + content.length + " chars",
                    isImage: false
                })
            }

            if (items.length >= root.maxItems)
                break
        }

        root.allItems = items

        if (!root.tabChosen && items.length > 0) {
            root.tab = items[0].isImage ? "image" : "text"
            root.tabChosen = true
        }

        root.listChecked = true
        root.rebuild()

        root.imageIds = ids

        if (ids.length > 0) {
            decodeProcess.running = false
            decodeProcess.running = true
        }
    }

    function rebuild() {
        var q = root.query.trim().toLowerCase()

        itemModel.clear()

        var ic = 0

        for (var j = 0; j < root.allItems.length; j++) {
            if (root.allItems[j].isImage)
                ic++
        }

        root.imageCount = ic
        root.textCount = root.allItems.length - ic

        for (var i = 0; i < root.allItems.length; i++) {
            var it = root.allItems[i]

            if (it.isImage !== (root.tab === "image"))
                continue

            if (q) {
                var hay = (
                    it.isImage
                    ? "image " + it.meta
                    : it.text
                ).toLowerCase()

                if (hay.indexOf(q) < 0)
                    continue
            }

            itemModel.append(it)
        }

        root.selIndex = 0
    }

    function setTab(name) {
        if (root.tab === name)
            return

        root.slideDir = name === "image" ? -1 : 1
        root.tab = name
        root.tabChosen = true
        root.rebuild()
        switchAnim.restart()
        autoCloseTimer.restart()
    }

    function pick(index) {
        if (index < 0 || index >= itemModel.count)
            return

        Quickshell.execDetached([
            "sh",
            "-c",
            "cliphist decode \"$1\" | wl-copy",
            "doiz",
            itemModel.get(index).clipId
        ])

        root.closePopup()
    }

    function removeItem(id) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "printf '%s\\t\\n' \"$1\" | cliphist delete",
            "doiz",
            id
        ])

        var kept = []

        for (var i = 0; i < root.allItems.length; i++) {
            if (root.allItems[i].clipId !== id)
                kept.push(root.allItems[i])
        }

        root.allItems = kept
        root.rebuild()
        autoCloseTimer.restart()
    }

    function removeSelected() {
        if (root.selIndex < 0 || root.selIndex >= itemModel.count)
            return

        root.removeItem(itemModel.get(root.selIndex).clipId)
    }

    function wipeAll() {
        if (!root.confirmClear) {
            root.confirmClear = true
            confirmTimer.restart()
            autoCloseTimer.restart()
            return
        }

        Quickshell.execDetached([
            "sh",
            "-c",
            "cliphist wipe; rm -rf \"$1\"",
            "doiz",
            root.cacheDir
        ])

        root.confirmClear = false
        root.allItems = []
        root.imageIds = []
        root.rebuild()
        autoCloseTimer.restart()
    }

    function move(delta) {
        if (itemModel.count === 0)
            return

        root.selIndex = Math.max(
            0,
            Math.min(itemModel.count - 1, root.selIndex + delta)
        )

        clipList.positionViewAtIndex(
            root.selIndex,
            ListView.Contain
        )

        autoCloseTimer.restart()
    }

    function refreshPopup() {
        root.query = ""
        root.confirmClear = false
        root.loadTheme()
        root.loadList()
        searchInput.forceActiveFocus()
        autoCloseTimer.restart()
    }

    function closePopup() {
        if (root.closingNow)
            return

        root.closingNow = true
        root.shown = false

        Quickshell.execDetached([
            "pkill",
            "-f",
            "qs (-c clipboard( -n)?|-p .*clipboard/shell\\.qml)$"
        ])

        Qt.quit()
        forceQuitTimer.start()
    }

    ListModel {
        id: itemModel
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
        id: clipboardPanel

        visible: root.shown

        focusable: true
        aboveWindows: true

        screen:
            Quickshell.screens.length > 0
            ? Quickshell.screens[0]
            : null

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore

        color: "transparent"

        WlrLayershell.namespace: "doiz-clipboard-panel"
        WlrLayershell.layer: WlrLayer.Overlay

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Shortcut {
            sequences: ["Escape"]

            onActivated: {
                root.closePopup()
            }
        }

        MouseArea {
            anchors.fill: parent

            acceptedButtons: Qt.AllButtons

            onPressed: {
                root.closePopup()
            }
        }

        Rectangle {
            id: panel
            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: Qt.lighter(root.accentColor, 1.3)
                c3: root.accentColor
                c4: Qt.lighter(root.accentColor, 1.3)
                cycle: 9000
            }

            anchors.centerIn: parent

            width: 720

            height: Math.min(
                840,
                contentColumn.implicitHeight + 24
            )

            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons
            }

            color: root.panelColor
            radius: 12

            border.width: 1

            border.color: root.tint(
                root.stateColor,
                0.35
            )

            Behavior on border.color {
                ColorAnimation {
                    duration: 250
                }
            }

            NumberAnimation on opacity {
                from: 0
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }

            transform: Translate {
                id: dipShift

                y: -6
            }

            scale: 0.97

            ParallelAnimation {
                id: dipAnim

                running: true

                NumberAnimation {
                    target: panel
                    property: "scale"
                    from: 0.97
                    to: 1
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }

                NumberAnimation {
                    target: dipShift
                    property: "y"
                    from: -6
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        autoCloseTimer.stop()
                    else
                        autoCloseTimer.restart()
                }
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
                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 40
                        height: 40

                        radius: 8

                        color: root.tint(
                            root.stateColor,
                            0.16
                        )

                        GlowText {
                            glowColor: root.iconColor
                            period: 2200
                            delay: 0
                            anchors.fill: parent

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            text: "󰅍"

                            color: root.iconColor

                            font.family: root.fontName
                            font.pixelSize: 21
                        }
                    }

                    Column {
                        anchors.left: iconTile.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 180

                        spacing: 2

                        Text {
                            width: parent.width

                            text: "CLIPBOARD"

                            color: root.mutedColor

                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold

                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width

                            text: root.statusText

                            color: root.titleColor

                            font.family: root.fontName
                            font.pixelSize: 11
                            font.weight: Font.DemiBold

                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 54
                        height: 40

                        radius: 8

                        color: root.cardColor

                        GlowText {
                            glowColor: root.iconColor
                            period: 3200
                            delay: 700
                            anchors.fill: parent

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            text: root.allItems.length

                            color: root.iconColor

                            font.family: root.fontName
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 34

                    radius: 8

                    color: root.cardColor

                    border.width: 1

                    border.color:
                        searchInput.activeFocus
                        ? root.tint(root.accentAltColor, 0.55)
                        : root.lineColor

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    GlowText {
                        glowColor: root.toneB
                        period: 2500
                        delay: 260
                        color: root.toneB
                        id: searchIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text: "󰍉"
                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: searchInput

                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter:
                            parent.verticalCenter

                        focus: true
                        clip: true

                        color: root.titleColor

                        selectionColor: root.accentColor
                        selectedTextColor: root.titleColor

                        font.family: root.fontName
                        font.pixelSize: 11

                        onTextChanged: {
                            if (root.query !== text) {
                                root.query = text
                                root.rebuild()
                            }

                            autoCloseTimer.restart()
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.closePopup()
                                event.accepted = true
                            } else if (
                                event.key === Qt.Key_Down ||
                                (
                                    event.key === Qt.Key_N &&
                                    (event.modifiers & Qt.ControlModifier)
                                )
                            ) {
                                root.move(1)
                                event.accepted = true
                            } else if (
                                event.key === Qt.Key_Up ||
                                (
                                    event.key === Qt.Key_P &&
                                    (event.modifiers & Qt.ControlModifier)
                                )
                            ) {
                                root.move(-1)
                                event.accepted = true
                            } else if (
                                event.key === Qt.Key_Return ||
                                event.key === Qt.Key_Enter
                            ) {
                                root.pick(root.selIndex)
                                event.accepted = true
                            } else if (
                                event.key === Qt.Key_Tab ||
                                event.key === Qt.Key_Backtab
                            ) {
                                root.setTab(
                                    root.tab === "image"
                                    ? "text"
                                    : "image"
                                )
                                event.accepted = true
                            } else if (
                                event.key === Qt.Key_Delete
                            ) {
                                root.removeSelected()
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter:
                                parent.verticalCenter

                            visible: searchInput.text.length === 0

                            text: "Search clipboard"

                            color: root.mutedColor

                            font.family: root.fontName
                            font.pixelSize: 11
                        }
                    }
                }

                Item {
                    id: tabHost

                    width: parent.width
                    height: 34

                    Rectangle {
                        id: tabIndicator

                        x: root.tab === "image"
                           ? 0
                           : (tabHost.width + 6) / 2

                        width: (tabHost.width - 6) / 2
                        height: 34

                        radius: 8

                        color: root.tint(root.accentColor, 0.22)

                        border.width: 1
                        border.color: root.tint(root.accentAltColor, 0.6)

                        Behavior on x {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }
                    }

                Row {
                    id: tabRow

                    anchors.fill: parent

                    spacing: 6

                    Repeater {
                        model: [
                            { key: "image", label: "Images", icon: "󰋩" },
                            { key: "text", label: "Text", icon: "󰧭" }
                        ]

                        delegate: Rectangle {
                            id: tabBtn

                            property bool active:
                                root.tab === modelData.key

                            property int cnt:
                                modelData.key === "image"
                                ? root.imageCount
                                : root.textCount

                            width: (tabRow.width - 6) / 2
                            height: 34

                            radius: 8

                            color:
                                active
                                ? "transparent"
                                : tabMouse.containsMouse
                                  ? root.tint(root.accentColor, 0.10)
                                  : root.cardColor

                            border.width: 1

                            border.color:
                                active
                                ? "transparent"
                                : root.lineColor

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Row {
                                anchors.centerIn: parent

                                spacing: 8

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    text: modelData.icon

                                    color:
                                        tabBtn.active
                                        ? root.toneB
                                        : root.mutedColor

                                    font.family: root.fontName
                                    font.pixelSize: 15
                                }

                                Text {
                                    anchors.verticalCenter:
                                        parent.verticalCenter

                                    text: modelData.label + "  " + tabBtn.cnt

                                    color:
                                        tabBtn.active
                                        ? root.titleColor
                                        : root.textColor

                                    font.family: root.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: tabMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.setTab(modelData.key)
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
                }

                Row {
                    id: controlRow

                    width: parent.width
                    height: 44

                    spacing: 6

                    Rectangle {
                        id: deleteButton

                        width: (controlRow.width - 6) / 2
                        height: 44

                        radius: 8

                        opacity: itemModel.count > 0 ? 1 : 0.45

                        color:
                            deleteMouse.containsMouse &&
                            itemModel.count > 0
                            ? root.tint(root.accentColor, 0.18)
                            : root.cardColor

                        border.width: 1
                        border.color: root.lineColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            anchors.centerIn: parent

                            spacing: 8

                            GlowText {
                                glowColor: root.toneB
                                period: 2800
                                delay: 520
                                color: root.toneB
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text: "󰆴"
                                font.family: root.fontName
                                font.pixelSize: 16
                            }

                            Text {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text: "Delete"

                                color: root.textColor

                                font.family: root.fontName
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: deleteMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                root.removeSelected()
                            }
                        }
                    }

                    Rectangle {
                        id: clearButton

                        width: (controlRow.width - 6) / 2
                        height: 44

                        radius: 8

                        opacity: root.available ? 1 : 0.45

                        color:
                            root.confirmClear
                            ? root.tint(root.dangerColor, 0.22)
                            : clearMouse.containsMouse &&
                              root.available
                              ? root.tint(root.accentColor, 0.18)
                              : root.cardColor

                        border.width: 1

                        border.color:
                            root.confirmClear
                            ? root.dangerColor
                            : root.lineColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            anchors.centerIn: parent

                            spacing: 8

                            GlowText {
                                glowColor: root.toneB
                                period: 3100
                                delay: 780
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text: "󰗩"

                                color:
                                    root.confirmClear
                                    ? root.dangerColor
                                    : root.textColor

                                font.family: root.fontName
                                font.pixelSize: 16
                            }

                            Text {
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                text:
                                    root.confirmClear
                                    ? "Sure?"
                                    : "Clear all"

                                color:
                                    root.confirmClear
                                    ? root.dangerColor
                                    : root.textColor

                                font.family: root.fontName
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: clearMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                if (root.available)
                                    root.wipeAll()
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
                    width: parent.width
                    height: 20

                    spacing: 8

                    GlowText {
                        glowColor: root.infoColor
                        period: 2200
                        delay: 1040
                        width: 18
                        height: parent.height

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text: "󰅍"

                        color: root.infoColor

                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    Text {
                        width: parent.width - 26
                        height: parent.height

                        verticalAlignment:
                            Text.AlignVCenter

                        text: root.tab === "image" ? "RECENT IMAGES" : "RECENT TEXT"

                        color: root.mutedColor

                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight:
                            Font.DemiBold
                    }
                }

                Item {
                    id: listHolder

                    width: parent.width
                    clip: true

                    height:
                        itemModel.count > 0
                        ? Math.min(clipList.contentHeight, root.tab === "image" ? 520 : 480)
                        : 44

                    Behavior on height {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }

                    ParallelAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: clipList
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: listShift
                            property: "x"
                            from: root.slideDir * 48
                            to: 0
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.fill: parent

                        visible: itemModel.count === 0

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            !root.listChecked
                            ? "Loading..."
                            : root.available
                              ? (root.query.trim() !== ""
                                 ? "No matches"
                                 : root.tab === "image"
                                   ? "No images"
                                   : "No text")
                              : "Nothing copied yet"

                        color: root.mutedColor

                        font.family: root.fontName
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    ListView {
                        id: clipList

                        anchors.fill: parent

                        visible: itemModel.count > 0

                        model: itemModel
                        spacing: 5
                        clip: true

                        transform: Translate {
                            id: listShift
                        }

                        boundsBehavior:
                            Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 2

                                color: root.accentColor
                                opacity: 0.55
                            }
                        }

                        delegate: Rectangle {
                            id: card

                            width: clipList.width
                            height: model.isImage ? 124 : 44

                            radius: 8

                            property bool selected:
                                index === root.selIndex

                            color:
                                cardMouse.containsMouse
                                ? root.tint(
                                    root.accentColor,
                                    0.12
                                  )
                                : root.cardColor

                            border.width: selected ? 1 : 0
                            border.color: root.connectedColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            MouseArea {
                                id: cardMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onEntered: {
                                    root.selIndex = index
                                    autoCloseTimer.restart()
                                }

                                onClicked: {
                                    root.pick(index)
                                }
                            }

                            Item {
                                id: thumb

                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                width: model.isImage ? 192 : 22
                                height: model.isImage ? 108 : 22

                                Text {
                                    anchors.fill: parent

                                    visible:
                                        !model.isImage ||
                                        thumbImage.status !==
                                        Image.Ready

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    text:
                                        model.isImage
                                        ? "󰋩"
                                        : "󰧭"

                                    color:
                                        card.selected
                                        ? root.connectedColor
                                        : root.mutedColor

                                    font.family: root.fontName
                                    font.pixelSize: model.isImage ? 32 : 16
                                }

                                Rectangle {
                                    anchors.fill: parent

                                    visible:
                                        model.isImage &&
                                        thumbImage.status ===
                                        Image.Ready

                                    radius: 6
                                    clip: true
                                    color: root.trackColor

                                    Image {
                                        id: thumbImage

                                        anchors.fill: parent

                                        source:
                                            model.isImage &&
                                            root.imageRev > 0
                                            ? "file://" +
                                              root.cacheDir +
                                              "/" +
                                              model.clipId
                                            : ""

                                        fillMode:
                                            Image.PreserveAspectCrop

                                        asynchronous: true
                                        cache: false

                                        sourceSize.width: 384
                                        sourceSize.height: 216
                                    }
                                }
                            }

                            Column {
                                anchors.left: thumb.right
                                anchors.leftMargin: 10
                                anchors.right: trashButton.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing: 2

                                Text {
                                    width: parent.width

                                    text: model.text

                                    color: root.titleColor

                                    font.family: root.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold

                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width

                                    text: model.meta

                                    color: root.mutedColor

                                    font.family: root.fontName
                                    font.pixelSize: 9

                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: trashButton

                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter:
                                    parent.verticalCenter

                                width: 26
                                height: 26

                                radius: 8

                                opacity:
                                    cardMouse.containsMouse ||
                                    trashMouse.containsMouse
                                    ? 1
                                    : 0

                                enabled: opacity > 0

                                color:
                                    trashMouse.containsMouse
                                    ? root.tint(
                                        root.dangerColor,
                                        0.2
                                      )
                                    : "transparent"

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }

                                Text {
                                    anchors.fill: parent

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    text: "󰅖"

                                    color:
                                        trashMouse.containsMouse
                                        ? root.dangerColor
                                        : root.mutedColor

                                    font.family: root.fontName
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: trashMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.removeItem(
                                            model.clipId
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: forceQuitTimer

        interval: 250
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                "pkill", "-9", "-f",
                "qs (-c clipboard( -n)?|-p .*clipboard/shell\\.qml)$"
            ])
            Qt.quit()
        }
    }

    Timer {
        id: confirmTimer

        interval: 3000
        repeat: false

        onTriggered: {
            root.confirmClear = false
        }
    }

    Timer {
        id: themeRefreshTimer

        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            root.loadTheme()
        }
    }

    Timer {
        id: autoCloseTimer

        interval: 8000
        repeat: false
        running: true

        onTriggered: {
            root.closePopup()
        }
    }

    Process {
        id: themeProcess

        command: [
            "sh",
            "-c",
            "if [ -f \"$1\" ]; then cat \"$1\"; fi",
            "doiz",
            root.themeFile
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseTheme(this.text)
            }
        }
    }

    Process {
        id: listProcess

        command: [
            "sh",
            "-c",
            "cliphist list 2>/dev/null | head -n \"$1\"",
            "doiz",
            String(root.maxItems)
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseList(this.text)
            }
        }
    }

    Process {
        id: decodeProcess

        command: [
            "sh",
            "-c",
            "d=\"$1\"; shift; mkdir -p \"$d\"; " +
            "for id in \"$@\"; do " +
            "[ -s \"$d/$id\" ] || " +
            "cliphist decode \"$id\" > \"$d/$id\" 2>/dev/null; " +
            "done",
            "doiz",
            root.cacheDir
        ].concat(root.imageIds)

        onExited: {
            root.imageRev += 1
        }
    }

    Component.onCompleted: {
        root.loadTheme()
        root.loadList()
        searchInput.forceActiveFocus()
    }
}
