import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property int activeIndex: 0
    property int slideDir: 1
    property string mode: "classic"
    readonly property int visibleRows: 10

    IpcHandler {
        target: "keybinds"

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

        function refresh(): void {
            root.loadMode()
        }
    }

    property string themeFile:
        (
            Quickshell.env("XDG_CONFIG_HOME") ||
            (
                Quickshell.env("HOME") +
                "/.config"
            )
        ) + "/theme/theme.conf"

    property color basePanelColor: "#f21b1d2d"
    property color baseCardColor: "#1a8e96ad"
    property color baseTrackColor: "#338e96ad"
    property color lineColor: "#40747e9d"
    property color titleColor: "#e8eaf3"
    property color textColor: "#c7ccda"
    property color mutedColor: "#8e96ad"
    property color accentColor: "#8a8a8a"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color whiteColor: "#ffffff"
    property string fontName: "JetBrainsMono Nerd Font"

    readonly property var categories: [
        {
            name: "APPS",
            entries: [
                { k: ["SUPER"], d: "Launcher" },
                { k: ["SUPER", "T"], d: "Terminal" },
                { k: ["SUPER", "W"], d: "Browser" },
                { k: ["SUPER", "E"], d: "File manager" },
                { k: ["SUPER", "N"], d: "Control center" },
                { k: ["SUPER", "I"], d: "Settings" },
                { k: ["SUPER", "V"], d: "Clipboard history" },
                { k: ["CTRL", "SHIFT", "Escape"], d: "Task manager (btop)" },
                { k: ["SUPER", "H"], d: "Keybinds / Help" },
                { k: ["SUPER", "M"], d: "Spotify" },
                { k: ["SUPER", "C"], d: "Cava desktop visualizer (cycle)" },
                { k: ["SUPER", "SHIFT", "W"], d: "Wallpaper picker (images + videos, carousel)" },
                { k: ["SUPER", "ALT", "W"], d: "Random wallpaper" }
            ]
        },
        {
            name: "WINDOWS",
            entries: [
                { k: ["SUPER", "Q"], d: "Close window" },
                { k: ["SUPER", "F"], d: "Fullscreen" },
                { k: ["SUPER", "ALT", "F"], d: "Maximize" },
                { k: ["SUPER", "ALT", "Space"], d: "Toggle floating" },
                { k: ["SUPER", "P"], d: "Pin window" },
                { k: ["CTRL", "SUPER", "\\"], d: "Center window" },
                { k: ["SUPER", "X"], d: "Resize window (hold)" }
            ]
        },
        {
            name: "WORKSPACES",
            entries: [
                { k: ["SUPER", "1-0"], d: "Go to workspace" },
                { k: ["SUPER", "ALT", "1-0"], d: "Move window to workspace" },
                { k: ["CTRL", "SUPER", "1-0"], d: "Go to workspace group" },
                { k: ["CTRL", "SUPER", "ALT", "1-0"], d: "Move window to group" },
                { k: ["SUPER", "Scroll"], d: "Previous / next workspace" },
                { k: ["SUPER", "Tab"], d: "Workspace overview next (Shift = back)" },
                { k: ["ALT", "Tab"], d: "Window switcher (Shift = back)" },
                { k: ["CTRL", "SUPER", "SHIFT", "↓"], d: "Return from scratchpad" },
                { k: ["SUPER", "S"], d: "Toggle scratchpad" },
                { k: ["SUPER", "ALT", "S"], d: "Send to scratchpad" }
            ]
        },
        {
            name: "INFINITE DESKTOP",
            entries: [
                { k: ["SUPER", "SHIFT", "D"], d: "Toggle Infinite Desktop ON / OFF" },
                { k: ["SUPER", "D"], d: "Toggle floating / tiled" },
                { k: ["SUPER", "SHIFT", "A"], d: "Auto Arrange Grid ON / OFF" },
                { k: ["SUPER", "SHIFT", "B"], d: "Judgement Cut slashes the screen and closes all apps" },
                { k: ["SUPER", "CTRL", "SHIFT", "B"], d: "Judgement Cut test (apps are not closed)" },
                { k: ["SUPER", "ALT", "B"], d: "Close-effect picker with live previews (Judgement / Portal / Ice / Glass / Black Hole)" },
                { k: ["SUPER", "←↑↓→"], d: "Navigate / focus windows" },
                { k: ["SUPER", "SHIFT", "←↑↓→"], d: "Move floating window" },
                { k: ["SUPER", "ALT", "←↑↓→"], d: "Move tiled window" },
                { k: ["SUPER", "CTRL", "ALT", "←↑↓→"], d: "Resize window" },
                { k: ["SUPER", "SHIFT", "Hold LMB"], d: "Pan the whole canvas (drag desktop)" },
                { k: ["SUPER", "ALT", "Scroll"], d: "Zoom the canvas in / out" },
                { k: ["SUPER", "ALT", "A"], d: "Reset canvas zoom to default" },
                { k: ["SUPER", "Hold LMB"], d: "Drag app window" }
            ]
        },
        {
            name: "CLIPBOARD",
            entries: [
                { k: ["SUPER", "V"], d: "Open clipboard history" },
                { k: ["SUPER", "ALT", "V"], d: "Clear clipboard history" }
            ]
        },
        {
            name: "CAPTURE & RECORD",
            entries: [
                { k: ["Print"], d: "Screenshot" },
                { k: ["SUPER", "SHIFT", "S"], d: "Area screenshot" },
                { k: ["CTRL", "ALT", "R"], d: "Screen record (no audio) start / stop" },
                { k: ["SUPER", "ALT", "R"], d: "Screen record (with audio)" },
                { k: ["SUPER", "SHIFT", "ALT", "R"], d: "Screen record (region)" }
            ]
        },
        {
            name: "SYSTEM",
            entries: [
                { k: ["SUPER", "L"], d: "Lock screen" },
                { k: ["SUPER", "SHIFT", "R"], d: "Reload Hyprland" }
            ]
        },
        {
            name: "MEDIA KEYS",
            entries: [
                { k: ["Vol+", "Vol-"], d: "Volume up / down (5%)" },
                { k: ["Mute"], d: "Mute / unmute speakers" },
                { k: ["Mic Mute"], d: "Mute / unmute microphone" },
                { k: ["Bright+", "Bright-"], d: "Screen brightness up / down (5%)" },
                { k: ["Play/Pause"], d: "Play / pause media" },
                { k: ["Next", "Prev"], d: "Next / previous track" }
            ]
        },
        {
            name: "LAUNCHER",
            entries: [
                { k: ["Tab"], d: "Next mode (Apps / Run / Windows / Wallpaper)" },
                { k: ["↑", "↓"], d: "Move selection (grid rows in Wallpaper)" },
                { k: ["←", "→"], d: "Wallpaper grid: previous / next" },
                { k: ["Enter"], d: "Run / open selected item" },
                { k: ["Esc"], d: "Close launcher" }
            ]
        },
        {
            name: "CLIPBOARD POPUP",
            entries: [
                { k: ["↑", "↓"], d: "Move selection" },
                { k: ["CTRL", "P"], d: "Previous entry" },
                { k: ["CTRL", "N"], d: "Next entry" },
                { k: ["Enter"], d: "Copy selected entry" },
                { k: ["Delete"], d: "Remove selected entry" },
                { k: ["Esc"], d: "Close clipboard" }
            ]
        },
        {
            name: "POPUPS & GESTURES",
            entries: [
                { k: ["Enter"], d: "Network: connect with typed password / Wallpaper: save folder" },
                { k: ["Esc"], d: "Network: cancel password entry" },
                { k: ["Esc"], d: "Close this help" },
                { k: ["↑", "↓"], d: "Settings: previous / next page (J / K also work)" },
                { k: ["Esc"], d: "Settings: close" },
                { k: ["SUPER", "H"], d: "Close this help" },
                { k: ["3-finger", "Swipe"], d: "Touchpad: switch workspace" }
            ]
        }
    ]

    function availableIndexes(currentMode) {
        var result = []

        for (var i = 0; i < root.categories.length; i++)
            result.push(i)

        return result
    }

    function categoryCount(currentMode) {
        return Math.max(
            1,
            root.availableIndexes(currentMode).length
        )
    }

    function categoryPosition(currentMode) {
        return Math.max(
            1,
            root.availableIndexes(currentMode).indexOf(
                root.activeIndex
            ) + 1
        )
    }

    function changeCategory(step) {
        var list = root.availableIndexes(root.mode)
        var position = list.indexOf(root.activeIndex)

        if (position < 0)
            position = 0

        position =
            (position + step + list.length) % list.length

        root.slideDir = step >= 0 ? 1 : -1
        root.activeIndex = list[position]
        switchAnim.restart()

        closeTimer.restart()
    }

    function loadTheme() {
        themeProcess.running = false
        themeProcess.running = true
    }

    function loadMode() {
        modeProcess.running = false
        modeProcess.running = true
    }

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

    function entriesFor(index, currentMode) {
        return root.categories[index].entries
    }

    function totalCount(currentMode) {
        var total = 0

        for (var i = 0; i < root.categories.length; i++)
            total += root.entriesFor(i, currentMode).length

        return total
    }

    function maxRows(currentMode) {
        var most = 0

        for (var i = 0; i < root.categories.length; i++)
            most = Math.max(most, root.entriesFor(i, currentMode).length)

        return most
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

        var ac = colors["accent_alt"] || colors["accent"]

        if (ac) {
            root.accentColor = ac
            root.lineColor = root.hexColor(ac, 0.3)
        }
    }

    function refreshPopup() {
        root.loadTheme()
        root.loadMode()
        closeTimer.restart()
    }

    function closePopup() {
        root.killPopup()
    }

    function killPopup() {
        root.shown = false
        killProcess.running = true
        killFallbackTimer.start()
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
        id: keybindsPanel

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

        WlrLayershell.namespace:
            "doiz-keybinds"

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.Exclusive

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
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 13000
            }

            anchors.centerIn: parent

            width: 420

            height: Math.min(
                940,
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
            border.color:
                root.tint(
                    root.accentColor,
                    0.45
                )

            Item {
                id: keyCatcher

                anchors.fill: parent
                focus: true

                Component.onCompleted: {
                    forceActiveFocus()
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.closePopup()
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Tab ||
                        event.key === Qt.Key_Right
                    ) {
                        root.changeCategory(1)
                        event.accepted = true
                    } else if (
                        event.key === Qt.Key_Backtab ||
                        event.key === Qt.Key_Left
                    ) {
                        root.changeCategory(-1)
                        event.accepted = true
                    }
                }
            }

            NumberAnimation on opacity {
                from: 0
                to: 1
                duration: 160
                easing.type:
                    Easing.OutCubic
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
                        closeTimer.stop()
                    else
                        closeTimer.restart()
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
                    height: 44

                    Rectangle {
                        id: iconTile

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42
                        height: 42
                        radius: 10
                        color: root.tint(root.toneB, 0.14)
                        border.width: 1
                        border.color: root.tint(root.toneB, 0.4)

                        GlowText {
                            anchors.centerIn: parent
                            text: "\uDB80\uDF0C"
                            glowColor: root.toneB
                            period: 2600
                            color: root.toneB
                            font.family: root.fontName
                            font.pixelSize: 22
                        }
                    }

                    Column {
                        anchors.left: iconTile.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 240
                        spacing: 3

                        Text {
                            width: parent.width
                            text: "KEYBINDS"
                            color: root.textColor
                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        GlowText {
                            width: parent.width
                            text: root.mode === "infinite"
                                  ? "Infinite Desktop: ON"
                                  : "Infinite Desktop: OFF"
                            glowColor: root.accentColor
                            period: 3200
                            delay: 400
                            color: root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56
                        height: 42
                        radius: 8
                        color: root.tint(root.accentColor, 0.14)
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.4)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.totalCount(root.mode)
                                color: root.titleColor
                                font.family: root.fontName
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "binds"
                                color: root.accentColor
                                font.family: root.fontName
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: root.trackColor

                    Rectangle {
                        width: parent.width *
                               (root.categoryPosition(root.mode) /
                                root.categoryCount(root.mode))
                        height: parent.height
                        radius: 3

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.accentColor }
                            GradientStop { position: 1.0; color: root.toneB }
                        }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            autoPaddingEnabled: true
                            shadowEnabled: true
                            shadowColor: root.toneB
                            shadowBlur: 1.0
                            shadowOpacity: 0.7
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
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
                        id: previousButton

                        width: (controlRow.width - 12) / 3
                        height: 44
                        radius: 8
                        color: root.tint(root.accentColor,
                                         previousMouse.containsMouse ? 0.30 : 0.14)
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.4)

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "\uDB80\uDD41"
                            color: previousMouse.containsMouse ? root.titleColor : root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: previousMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeCategory(-1)
                        }
                    }

                    Rectangle {
                        id: currentButton

                        width: (controlRow.width - 12) / 3
                        height: 44
                        radius: 8
                        color: root.tint(root.toneB, 0.16)
                        border.width: 1
                        border.color: root.tint(root.toneB, 0.5)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.categoryPosition(root.mode) +
                                      " / " +
                                      root.categoryCount(root.mode)
                                color: root.titleColor
                                font.family: root.fontName
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "category"
                                color: root.toneB
                                font.family: root.fontName
                                font.pixelSize: 8
                            }
                        }
                    }

                    Rectangle {
                        id: nextButton

                        width: (controlRow.width - 12) / 3
                        height: 44
                        radius: 8
                        color: root.tint(root.accentColor,
                                         nextMouse.containsMouse ? 0.30 : 0.14)
                        border.width: 1
                        border.color: root.tint(root.accentColor, 0.4)

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "\uDB80\uDD42"
                            color: nextMouse.containsMouse ? root.titleColor : root.accentColor
                            font.family: root.fontName
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeCategory(1)
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
                        width: 18
                        height: parent.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "\uDB80\uDF0C"
                        glowColor: root.toneB
                        period: 2200
                        color: root.toneB
                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    Text {
                        width: parent.width - 26
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: root.categories[root.activeIndex].name +
                              "  " +
                              root.entriesFor(root.activeIndex, root.mode).length
                        color: root.textColor
                        font.family: root.fontName
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                Item {
                    width: parent.width
                    height: root.visibleRows * 54 - 6
                    clip: true

                    ParallelAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: entryList
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: entryShift
                            property: "x"
                            from: root.slideDir * 56
                            to: 0
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }

                    ListView {
                        id: entryList

                        transform: Translate {
                            id: entryShift
                        }

                        anchors.fill: parent
                        model: root.entriesFor(root.activeIndex, root.mode)
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 3
                                radius: 2
                                color: root.toneB
                                opacity: 0.55
                            }
                        }

                        delegate: Rectangle {
                            id: entry

                            required property var modelData
                            required property int index

                            readonly property color tone: index % 2 === 0 ? root.toneB : root.accentColor

                            width: entryList.width
                            height: 48
                            radius: 8
                            color: root.tint(entry.tone, entryMouse.containsMouse ? 0.26 : 0.12)
                            border.width: 1
                            border.color: root.tint(entry.tone, entryMouse.containsMouse ? 0.6 : 0.35)

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                GlowText {
                                    width: 22
                                    height: parent.height
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "\uDB80\uDF0C"
                                    glowColor: entry.tone
                                    period: 2200
                                    delay: entry.index * 260
                                    color: entry.tone
                                    font.family: root.fontName
                                    font.pixelSize: 16
                                }

                                Column {
                                    width: parent.width - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 5

                                    Text {
                                        width: parent.width
                                        text: entry.modelData.d.toUpperCase()
                                        color: root.textColor
                                        font.family: root.fontName
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        spacing: 3

                                        Repeater {
                                            model: entry.modelData.k

                                            delegate: Row {
                                                id: keyCell

                                                required property string modelData
                                                required property int index

                                                spacing: 3

                                                Rectangle {
                                                    width: keyText.implicitWidth + 12
                                                    height: 18
                                                    radius: 5
                                                    color: root.tint(entry.tone, 0.18)
                                                    border.width: 1
                                                    border.color: root.tint(entry.tone, 0.55)

                                                    Text {
                                                        id: keyText

                                                        anchors.centerIn: parent
                                                        text: keyCell.modelData
                                                        color: root.titleColor
                                                        font.family: root.fontName
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                    }
                                                }

                                                Text {
                                                    height: 18
                                                    visible: keyCell.index < entry.modelData.k.length - 1
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "+"
                                                    color: root.mutedColor
                                                    font.family: root.fontName
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: entryMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: closeTimer.restart()
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 18
                    spacing: 8

                    GlowText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uDB80\uDF0C"
                        glowColor: root.toneB
                        period: 2600
                        delay: 300
                        color: root.toneB
                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ESC or SUPER + H to close"
                        color: root.mutedColor
                        font.family: root.fontName
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer

        interval: 20000
        repeat: false
        running: true

        onTriggered: {
            root.closePopup()
        }
    }

    Timer {
        id: themeRefreshTimer

        interval: 2000
        repeat: true
        running: true

        onTriggered: {
            root.loadTheme()
        }
    }

    Process {
        id: killProcess

        command: [
            "pkill",
            "-f",
            "^(.*/)?(qs|quickshell) .*keybinds"
        ]
    }

    Timer {
        id: killFallbackTimer

        interval: 300
        repeat: false

        onTriggered: {
            Qt.quit()
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
        id: modeProcess

        command: [
            "sh",
            "-c",
            "if pgrep -f \"[p]ython3[[:space:]]+$HOME/.config/hypr/scripts/infinite-desktop/infinite_desktop_core.py([[:space:]]|$)\" >/dev/null 2>&1; then echo infinite; else echo classic; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.mode = this.text.trim()

                if (
                    root.availableIndexes(
                        root.mode
                    ).indexOf(root.activeIndex) < 0
                ) {
                    root.activeIndex = 0
                }
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.loadMode()
    }

    Component.onCompleted: {
        root.loadTheme()
        root.loadMode()
    }
}
