import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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

    property bool closing: false

    readonly property bool autoClose: false

    Timer {
        id: quitTimer

        interval: 250
        onTriggered: root.finishClose()
    }

    IpcHandler {
        target: "volume"

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

    property int volume: 0
    property bool muted: false
    property string device: "Default Output"
    property string deviceId: ""
    property var devices: []

    property color themeBackground: "#282525"
    property color themeSurface: "#464036"
    property color themeSurfaceAlt: "#605642"
    property color themeForeground: "#E0DFE4"
    property color themeSubtext: "#BBB9B7"
    property color themeMuted: "#8D8981"
    property color themeAccent: "#8C753F"
    property color themeBlue: "#8A9AAB"
    property color themeGreen: "#9DBB7E"
    property color themeRed: "#CE8382"
    property color themeYellow: "#C6A86F"

    property color basePanelColor: Qt.rgba(
        themeBackground.r,
        themeBackground.g,
        themeBackground.b,
        0.96
    )

    property color baseCardColor: Qt.rgba(
        themeSurface.r,
        themeSurface.g,
        themeSurface.b,
        0.92
    )

    property color baseTrackColor: Qt.rgba(
        themeSurfaceAlt.r,
        themeSurfaceAlt.g,
        themeSurfaceAlt.b,
        0.80
    )

    property color lineColor: Qt.rgba(
        themeMuted.r,
        themeMuted.g,
        themeMuted.b,
        0.30
    )

    property color titleColor: themeForeground
    property color textColor: themeSubtext
    property color mutedColor: themeMuted
    property color accentColor: themeAccent
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color infoColor: themeBlue
    property color warningColor: themeYellow
    property color dangerColor: themeRed
    property color connectedColor: themeGreen

    property string fontName: "JetBrainsMono Nerd Font"

    property color stateColor: root.muted
                               ? root.dangerColor
                               : root.accentColor

    function tint(c, alpha) {
        return Qt.rgba(
            c.r,
            c.g,
            c.b,
            alpha
        )
    }

    function parseColor(value, fallback) {
        var valueString = String(value || "").trim()

        if (!/^#[0-9a-fA-F]{6}$/.test(valueString))
            return fallback

        var r = parseInt(
            valueString.substring(1, 3),
            16
        ) / 255

        var g = parseInt(
            valueString.substring(3, 5),
            16
        ) / 255

        var b = parseInt(
            valueString.substring(5, 7),
            16
        ) / 255

        return Qt.rgba(r, g, b, 1)
    }

    function applyTheme(data) {
        var lines = data.split("\n")
        var colors = {}
        var inColors = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.length === 0)
                continue

            if (line.charAt(0) === "#")
                continue

            if (line === "[colors]") {
                inColors = true
                continue
            }

            if (line.charAt(0) === "[") {
                inColors = false
                continue
            }

            if (!inColors)
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
                continue

            var key = line
                .substring(0, separator)
                .trim()

            var value = line
                .substring(separator + 1)
                .trim()

            if (key.length === 0)
                continue

            colors[key] = value
        }

        if (colors.background)
            root.themeBackground =
                root.parseColor(
                    colors.background,
                    root.themeBackground
                )

        if (colors.surface)
            root.themeSurface =
                root.parseColor(
                    colors.surface,
                    root.themeSurface
                )

        if (colors.surface_alt)
            root.themeSurfaceAlt =
                root.parseColor(
                    colors.surface_alt,
                    root.themeSurfaceAlt
                )

        if (colors.foreground)
            root.themeForeground =
                root.parseColor(
                    colors.foreground,
                    root.themeForeground
                )

        if (colors.subtext)
            root.themeSubtext =
                root.parseColor(
                    colors.subtext,
                    root.themeSubtext
                )

        if (colors.muted)
            root.themeMuted =
                root.parseColor(
                    colors.muted,
                    root.themeMuted
                )

        if (colors.accent_alt || colors.accent)
            root.themeAccent =
                root.parseColor(
                    colors.accent_alt || colors.accent,
                    root.themeAccent
                )

        if (colors.blue)
            root.themeBlue =
                root.parseColor(
                    colors.blue,
                    root.themeBlue
                )

        if (colors.green)
            root.themeGreen =
                root.parseColor(
                    colors.green,
                    root.themeGreen
                )

        if (colors.red)
            root.themeRed =
                root.parseColor(
                    colors.red,
                    root.themeRed
                )

        if (colors.yellow)
            root.themeYellow =
                root.parseColor(
                    colors.yellow,
                    root.themeYellow
                )
    }

    function reloadTheme() {
        if (!themeProcess.running)
            themeProcess.running = true
    }

    function volumeIcon() {
        if (root.muted || root.volume <= 0)
            return "󰖁"

        if (root.volume < 35)
            return "󰕿"

        if (root.volume < 70)
            return "󰖀"

        return "󰕾"
    }

    function refresh() {
        if (!volumeProcess.running)
            volumeProcess.running = true

        if (!muteStateProcess.running)
            muteStateProcess.running = true

        if (!deviceProcess.running)
            deviceProcess.running = true

        if (!devicesProcess.running)
            devicesProcess.running = true
    }

    function setVolume(value) {
        var v = Math.max(
            0,
            Math.min(
                100,
                Math.round(value)
            )
        )

        root.volume = v
        autoCloseTimer.restart()

        volumeSetProcess.command = [
            "wpctl",
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            v + "%"
        ]

        volumeSetProcess.running = true
    }

    function changeVolume(amount) {
        root.setVolume(
            root.volume + amount
        )
    }

    function toggleMute() {
        muteToggleProcess.running = true
    }

    function selectDevice(id) {
        if (!id || id.length === 0)
            return

        root.deviceId = id

        deviceSetProcess.command = [
            "wpctl",
            "set-default",
            id
        ]

        deviceSetProcess.running = true
    }

    function parseDevices(data) {
        var result = []
        var cleaned = data.trim()

        if (cleaned.length === 0) {
            root.devices = result
            return
        }

        var lines = cleaned.split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.length === 0)
                continue

            var parts = line.split("\t")

            if (parts.length < 2)
                continue

            var id = parts[0].trim()
            var name = parts.slice(1).join("\t").trim()

            if (id.length === 0 || name.length === 0)
                continue

            if (!/^[0-9]+$/.test(id))
                continue

            result.push({
                id: id,
                name: name
            })
        }

        root.devices = result
    }

    function refreshPopup() {
        root.refresh()
        root.reloadTheme()
        autoCloseTimer.restart()
    }

    function closePopup() {
        if (root.closing)
            return

        root.closing = true
        quitTimer.start()
    }

    function finishClose() {
        Qt.quit()
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
        id: clickLayer

        visible: root.shown && !root.closing

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.namespace: "doiz-volume-click-layer"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closePopup()
            }
        }
    }

    PanelWindow {
        id: volumePanel

        visible: root.shown

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 8
        }

        implicitWidth: 340

        implicitHeight: Math.min(
            620,
            contentColumn.implicitHeight + 24
        )

        color: "transparent"

        WlrLayershell.namespace: "doiz-volume-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: panel
                        property bool panelShown: false
            Component.onCompleted: panelShown = true
            opacity: (panelShown && !root.closing) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            transform: Translate {
                y: (panelShown && !root.closing) ? 0 : 10
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            }
            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: Qt.lighter(root.accentColor, 1.3)
                c3: root.accentColor
                c4: Qt.lighter(root.accentColor, 1.3)
                cycle: 9000
            }

            anchors.fill: parent

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

            MouseArea {
                anchors.fill: parent

                onWheel: function(wheel) {
                    root.changeVolume(
                        wheel.angleDelta.y > 0 ? 5 : -5
                    )
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

                        border.width: 1
                        border.color: root.tint(
                            root.stateColor,
                            0.5
                        )

                        GlowText {
                            glowColor: root.stateColor
                            period: 2200
                            delay: 0
                            anchors.fill: parent

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            text: root.volumeIcon()

                            color: root.stateColor

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

                            text: "VOLUME"

                            color: root.mutedColor

                            font.family: root.fontName
                            font.pixelSize: 9
                            font.weight: Font.Bold

                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width

                            text: root.muted
                                  ? "Muted"
                                  : root.device

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

                        radius: 10

                        color: root.tint(root.stateColor, 0.16)

                        border.width: 1
                        border.color: root.tint(root.stateColor, 0.5)

                        GlowText {
                            glowColor: root.stateColor
                            period: 3200
                            delay: 400
                            anchors.fill: parent

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            text: root.volume + "%"

                            color: root.stateColor

                            font.family: root.fontName
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 8

                    radius: 4

                    color: root.trackColor

                    Rectangle {
                        width:
                            parent.width *
                            Math.max(
                                0,
                                Math.min(
                                    1,
                                    root.volume / 100
                                )
                            )

                        height: parent.height

                        radius: 4

                        color: root.stateColor

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onPressed: function(mouse) {
                            root.setVolume(
                                mouse.x /
                                width *
                                100
                            )
                        }

                        onPositionChanged:
                            function(mouse) {
                                if (pressed) {
                                    root.setVolume(
                                        mouse.x /
                                        width *
                                        100
                                    )
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
                        id: decreaseButton

                        width:
                            (controlRow.width - 12) / 3

                        height: 44

                        radius: 8

                        color:
                            decreaseMouse.containsMouse
                            ? root.tint(
                                root.accentColor,
                                0.18
                              )
                            : root.cardColor

                        border.width: 1
                        border.color: root.lineColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Item {
                            anchors.centerIn: parent

                            width: 22
                            height: 22

                            Rectangle {
                                anchors.centerIn:
                                    parent

                                width: 14
                                height: 2

                                radius: 1

                                color:
                                    root.textColor
                            }
                        }

                        MouseArea {
                            id: decreaseMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                root.changeVolume(-5)
                            }
                        }
                    }

                    Rectangle {
                        id: muteButton

                        width:
                            (controlRow.width - 12) / 3

                        height: 44

                        radius: 8

                        color:
                            root.muted
                            ? root.tint(
                                root.dangerColor,
                                0.16
                              )
                            : muteMouse.containsMouse
                              ? root.tint(
                                  root.accentColor,
                                  0.18
                                )
                              : root.cardColor

                        border.width: 1

                        border.color:
                            root.muted
                            ? root.dangerColor
                            : root.lineColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        GlowText {
                            glowColor: root.toneB
                            period: 2500
                            delay: 260
                            anchors.fill: parent

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            text: "󰓃"

                            color:
                                root.muted
                                ? root.dangerColor
                                : root.accentColor

                            font.family: root.fontName
                            font.pixelSize: 19
                        }

                        MouseArea {
                            id: muteMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                root.toggleMute()
                            }
                        }
                    }

                    Rectangle {
                        id: increaseButton

                        width:
                            (controlRow.width - 12) / 3

                        height: 44

                        radius: 8

                        color:
                            increaseMouse.containsMouse
                            ? root.tint(
                                root.accentColor,
                                0.18
                              )
                            : root.cardColor

                        border.width: 1
                        border.color: root.lineColor

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Item {
                            anchors.centerIn: parent

                            width: 22
                            height: 22

                            Rectangle {
                                anchors.centerIn:
                                    parent

                                width: 14
                                height: 2

                                radius: 1

                                color:
                                    root.textColor
                            }

                            Rectangle {
                                anchors.centerIn:
                                    parent

                                width: 2
                                height: 14

                                radius: 1

                                color:
                                    root.textColor
                            }
                        }

                        MouseArea {
                            id: increaseMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {
                                root.changeVolume(5)
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
                        period: 2800
                        delay: 520
                        width: 18
                        height: parent.height

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text: "󰓃"

                        color: root.infoColor

                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    Text {
                        width: parent.width - 26
                        height: parent.height

                        verticalAlignment:
                            Text.AlignVCenter

                        text: "OUTPUT DEVICE"

                        color: root.mutedColor

                        font.family: root.fontName
                        font.pixelSize: 8
                        font.weight:
                            Font.DemiBold
                    }
                }

                Column {
                    width: parent.width

                    spacing: 5

                    Repeater {
                        model: root.devices

                        delegate: Rectangle {
                            width: contentColumn.width
                            height: 44

                            radius: 8

                            color:
                                deviceMouse.containsMouse
                                ? root.tint(
                                    root.accentColor,
                                    0.12
                                  )
                                : root.cardColor

                            border.width:
                                root.deviceId ===
                                modelData.id
                                ? 1
                                : 0

                            border.color:
                                root.connectedColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Row {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                spacing: 10

                                Text {
                                    width: 22
                                    height: parent.height

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    text:
                                        root.deviceId ===
                                        modelData.id
                                        ? "󰄬"
                                        : "󰋼"

                                    color:
                                        root.deviceId ===
                                        modelData.id
                                        ? root.connectedColor
                                        : root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 16
                                }

                                Text {
                                    width:
                                        parent.width - 32

                                    height: parent.height

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    text: modelData.name

                                    color:
                                        root.deviceId ===
                                        modelData.id
                                        ? root.textColor
                                        : root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 10

                                    font.weight:
                                        root.deviceId ===
                                        modelData.id
                                        ? Font.Bold
                                        : Font.DemiBold

                                    elide:
                                        Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: deviceMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.selectDevice(
                                        modelData.id
                                    )
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
                    width: parent.width
                    height: 20

                    spacing: 8

                    GlowText {
                        glowColor: root.stateColor
                        period: 3100
                        delay: 780
                        width: 18
                        height: parent.height

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.muted
                            ? "󰖁"
                            : "󰕾"

                        color: root.stateColor

                        font.family: root.fontName
                        font.pixelSize: 14
                    }

                    Text {
                        width: parent.width - 26
                        height: parent.height

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            root.muted
                            ? "Audio output muted"
                            : root.volume +
                              "% • " +
                              root.device

                        color: root.textColor

                        font.family: root.fontName
                        font.pixelSize: 9
                        font.weight:
                            Font.DemiBold

                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Process {
        id: themeProcess

        command: [
            "bash",
            "-c",
            "config_dir=\"${XDG_CONFIG_HOME:-$HOME/.config}\"; cat \"$config_dir/theme/theme.conf\" 2>/dev/null || true"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.applyTheme(this.text)
            }
        }
    }

    Process {
        id: volumeProcess

        command: [
            "bash",
            "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var value =
                    parseInt(
                        this.text.trim()
                    )

                if (!isNaN(value)) {
                    root.volume =
                        Math.max(
                            0,
                            Math.min(
                                100,
                                value
                            )
                        )
                }
            }
        }
    }

    Process {
        id: muteStateProcess

        command: [
            "bash",
            "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.muted =
                    this.text.indexOf(
                        "[MUTED]"
                    ) !== -1
            }
        }
    }

    Process {
        id: deviceProcess

        command: [
            "bash",
            "-c",
            "id=$(wpctl status | awk '/Sinks:/{s=1; next} /^[^[:space:]]/{if(s) exit} s && /^[[:space:]]*\\*?[0-9]+\\./{gsub(/\\./,\"\",$1); print $1; exit}'); if [ -n \"$id\" ]; then printf '%s\\n' \"$id\"; wpctl inspect \"$id\" | grep -m1 'node.description' | sed 's/.*= //' | tr -d '\"'; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines =
                    this.text.trim().split("\n")

                if (lines.length >= 1) {
                    var id =
                        lines[0].trim()

                    if (/^[0-9]+$/.test(id))
                        root.deviceId = id
                }

                if (lines.length >= 2) {
                    var name =
                        lines.slice(
                            1
                        ).join(" ").trim()

                    if (name.length > 0)
                        root.device = name
                }
            }
        }
    }

    Process {
        id: devicesProcess

        command: [
            "bash",
            "-c",
            "wpctl status | awk '/Sinks:/{s=1; next} /^[^[:space:]]/{if(s) exit} s && /^[[:space:]]*[0-9]+\\./{id=$1; gsub(/\\./,\"\",id); $1=\"\"; sub(/^[[:space:]]+/,\"\"); print id \"\\t\" $0}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseDevices(
                    this.text
                )
            }
        }
    }

    Process {
        id: volumeSetProcess

        command: [
            "wpctl",
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            "0%"
        ]

        onExited: {
            refreshTimer.restart()
        }
    }

    Process {
        id: muteToggleProcess

        command: [
            "wpctl",
            "set-mute",
            "@DEFAULT_AUDIO_SINK@",
            "toggle"
        ]

        onExited: {
            refreshTimer.restart()
        }
    }

    Process {
        id: deviceSetProcess

        command: [
            "wpctl",
            "set-default",
            "0"
        ]

        onExited: {
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer

        interval: 200
        repeat: false

        onTriggered: {
            root.refresh()
        }
    }

    Timer {
        id: liveRefreshTimer

        interval: 1500
        repeat: true
        running: true

        onTriggered: {
            root.refresh()
        }
    }

    Timer {
        id: themeRefreshTimer

        interval: 2000
        repeat: true
        running: true

        onTriggered: {
            root.reloadTheme()
        }
    }

    Timer {
        id: autoCloseTimer

        interval: 5000
        repeat: false
        running: true

        onTriggered: {
            if (root.autoClose)
                root.closePopup()
        }
    }

    Component.onCompleted: {
        root.reloadTheme()
        root.refresh()
    }
}