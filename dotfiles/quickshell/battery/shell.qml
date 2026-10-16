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
        target: "battery"

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

    property string statusText: "Loading..."
    property string levelText: "--"
    property string timeText: "Time unavailable"
    property string powerText: "--"
    property string voltageText: "--"
    property string currentText: "--"
    property string healthText: "--"
    property string cyclesText: "--"
    property string wearText: "--"
    property string technologyText: "--"
    property string modelText: "--"
    property string manufacturerText: "--"
    property string fullCapacityText: "--"
    property string designCapacityText: "--"

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
    property color accentColor: "#b59edc"
    readonly property color toneB: Qt.lighter(accentColor, 1.3)
    property color chargingColor: "#b9d8c2"
    property color infoColor: "#9ec5e6"
    property color warningColor: "#e6c58a"
    property color orangeColor: "#e6a988"
    property color dangerColor: "#e6a8b8"
    property string fontName: "JetBrainsMono Nerd Font"

    property int levelValue:
        isNaN(parseInt(root.levelText))
        ? -1
        : parseInt(root.levelText)

    property bool isCharging:
        root.statusText === "Charging"

    property bool isPlugged:
        root.statusText === "Charging" ||
        root.statusText === "Not charging"

    property color levelColor:
        root.levelValue < 0
        ? root.mutedColor
        : root.levelValue >= 60
          ? root.chargingColor
          : root.levelValue >= 30
            ? root.warningColor
            : root.levelValue >= 15
              ? root.orangeColor
              : root.dangerColor

    property color stateColor:
        root.statusText === "Full"
        ? root.chargingColor
        : root.isPlugged
          ? root.infoColor
          : root.statusText === "Discharging"
            ? root.levelColor
            : root.mutedColor

    function loadBattery() {
        if (!batteryProcess.running)
            batteryProcess.running = true
    }

    function loadTheme() {
        themeProcess.running = false
        themeProcess.running = true
    }

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function batteryIcon() {
        if (root.statusText === "No battery")
            return "\uDB80\uDC91"

        if (root.isCharging)
            return "\uDB80\uDC84"

        if (root.levelValue < 0)
            return "\uDB80\uDC91"

        var suffix = [
            "83",
            "7A",
            "7B",
            "7C",
            "7D",
            "7E",
            "7F",
            "80",
            "81",
            "82",
            "79"
        ]

        var code = parseInt(
            suffix[
                Math.min(
                    10,
                    Math.floor(root.levelValue / 10)
                )
            ],
            16
        )

        return "\uDB80" +
               String.fromCharCode(
                   0xDC00 + code
               )
    }

    function healthColor(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return root.textColor

        if (v >= 80)
            return root.chargingColor

        if (v >= 60)
            return root.warningColor

        if (v >= 40)
            return root.orangeColor

        return root.dangerColor
    }

    function wearColor(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return root.textColor

        if (v <= 20)
            return root.chargingColor

        if (v <= 40)
            return root.warningColor

        if (v <= 60)
            return root.orangeColor

        return root.dangerColor
    }

    function cyclesColor(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return root.textColor

        if (v < 300)
            return root.chargingColor

        if (v < 600)
            return root.warningColor

        if (v < 1000)
            return root.orangeColor

        return root.dangerColor
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
                section =
                    line.substring(
                        1,
                        line.length - 1
                    )
                continue
            }

            if (section !== "colors")
                continue

            var separator = line.indexOf("=")

            if (separator < 0)
                continue

            var key =
                line.substring(
                    0,
                    separator
                ).trim()

            var value =
                line.substring(
                    separator + 1
                ).trim()

            colors[key] = value
        }

        if (colors["background"])
            root.basePanelColor =
                Qt.rgba(
                    parseInt(
                        colors["background"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["background"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["background"].substring(5, 7),
                        16
                    ) / 255,
                    0.95
                )

        if (colors["surface"])
            root.baseCardColor =
                Qt.rgba(
                    parseInt(
                        colors["surface"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface"].substring(5, 7),
                        16
                    ) / 255,
                    0.62
                )

        if (colors["surface_alt"])
            root.baseTrackColor =
                Qt.rgba(
                    parseInt(
                        colors["surface_alt"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface_alt"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["surface_alt"].substring(5, 7),
                        16
                    ) / 255,
                    0.35
                )

        if (colors["foreground"])
            root.titleColor =
                colors["foreground"]

        if (colors["subtext"])
            root.textColor =
                colors["subtext"]

        if (colors["muted"])
            root.mutedColor =
                colors["muted"]

        if (colors["accent"])
            root.accentColor =
                (colors["accent_alt"] || colors["accent"])

        if (colors["green"])
            root.chargingColor =
                colors["green"]

        if (colors["blue"])
            root.infoColor =
                colors["blue"]

        if (colors["yellow"])
            root.warningColor =
                colors["yellow"]

        if (colors["orange"])
            root.orangeColor =
                colors["yellow"]

        if (colors["red"])
            root.dangerColor =
                colors["red"]

        if (colors["accent"])
            root.lineColor =
                Qt.rgba(
                    parseInt(
                        colors["accent"].substring(1, 3),
                        16
                    ) / 255,
                    parseInt(
                        colors["accent"].substring(3, 5),
                        16
                    ) / 255,
                    parseInt(
                        colors["accent"].substring(5, 7),
                        16
                    ) / 255,
                    0.25
                )
    }

    function parseBattery(data) {
        var lines = data.trim().split("\n")
        var values = {}

        for (var i = 0; i < lines.length; i++) {
            var separator =
                lines[i].indexOf("=")

            if (separator < 0)
                continue

            var key =
                lines[i].substring(
                    0,
                    separator
                )

            var value =
                lines[i].substring(
                    separator + 1
                )

            values[key] = value
        }

        if (values["FOUND"] === "0") {
            root.statusText = "No battery"
            root.levelText = "--"
            root.timeText = "Battery unavailable"
            root.powerText = "--"
            root.voltageText = "--"
            root.currentText = "--"
            root.healthText = "--"
            root.cyclesText = "--"
            root.wearText = "--"
            root.technologyText = "--"
            root.modelText = "--"
            root.manufacturerText = "--"
            root.fullCapacityText = "--"
            root.designCapacityText = "--"
            return
        }

        root.statusText =
            values["STATUS"] || "Unknown"

        root.levelText =
            values["CAPACITY"] || "--"

        root.timeText =
            values["TIME"] || "Time unavailable"

        root.powerText =
            values["POWER"] || "--"

        root.voltageText =
            values["VOLTAGE"] || "--"

        root.currentText =
            values["CURRENT"] || "--"

        root.healthText =
            values["HEALTH"] || "--"

        root.cyclesText =
            values["CYCLES"] || "--"

        root.wearText =
            values["WEAR"] || "--"

        root.technologyText =
            values["TECHNOLOGY"] || "--"

        root.modelText =
            values["MODEL"] || "--"

        root.manufacturerText =
            values["MANUFACTURER"] || "--"

        root.fullCapacityText =
            values["FULL_CAPACITY"] || "--"

        root.designCapacityText =
            values["DESIGN_CAPACITY"] || "--"
    }

    function refreshPopup() {
        root.loadTheme()
        root.loadBattery()
        closeTimer.restart()
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

        WlrLayershell.namespace:
            "doiz-battery-click-layer"

        WlrLayershell.layer:
            WlrLayer.Top

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.closePopup()
            }
        }
    }

    PanelWindow {
        id: batteryPanel

        visible: root.shown

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 8
        }

        implicitWidth: 320
        implicitHeight:
            contentColumn.implicitHeight + 24

        color: "transparent"

        WlrLayershell.namespace:
            "doiz-battery"

        WlrLayershell.layer:
            WlrLayer.Overlay

        WlrLayershell.keyboardFocus:
            WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent

            color: root.panelColor
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
            radius: 12

            border.width: 1
            border.color:
                root.tint(
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
                easing.type:
                    Easing.OutCubic
            }

            Column {
                id: contentColumn

                x: 12
                y: 12

                width:
                    parent.width - 24

                spacing: 8

                Item {
                    width: parent.width
                    height: 40

                    Rectangle {
                        id: iconTile

                        anchors.left:
                            parent.left

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 40
                        height: 40
                        radius: 8

                        color:
                            root.tint(
                                root.stateColor,
                                0.16
                            )

                        GlowText {
                            glowColor: root.stateColor
                            period: 2200
                            delay: 0
                            anchors.centerIn:
                                parent

                            text:
                                root.batteryIcon()

                            color:
                                root.stateColor

                            font.family:
                                root.fontName

                            font.pixelSize: 21
                        }
                    }

                    Column {
                        anchors.left:
                            iconTile.right

                        anchors.leftMargin: 10

                        anchors.verticalCenter:
                            parent.verticalCenter

                        spacing: 2

                        Text {
                            text: "BATTERY"

                            color: root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 9

                            font.weight:
                                Font.Bold
                        }

                        Text {
                            text:
                                root.statusText

                            color: root.titleColor

                            font.family:
                                root.fontName

                            font.pixelSize: 11

                            font.weight:
                                Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.right:
                            parent.right

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width: 54
                        height: 40
                        radius: 8

                        color:
                            root.cardColor

                        GlowText {
                            glowColor: root.stateColor
                            period: 3200
                            delay: 1000
                            anchors.centerIn:
                                parent

                            text:
                                root.levelValue >= 0
                                ? root.levelValue + "%"
                                : "--"

                            color:
                                root.stateColor

                            font.family:
                                root.fontName

                            font.pixelSize: 12

                            font.weight:
                                Font.Bold
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6

                    radius: 3

                    color:
                        root.trackColor

                    Rectangle {
                        width:
                            parent.width *
                            Math.max(
                                0,
                                Math.min(
                                    1,
                                    root.levelValue / 100
                                )
                            )

                        height: parent.height

                        radius: 3

                        color:
                            root.stateColor

                        Behavior on width {
                            NumberAnimation {
                                duration: 400
                                easing.type:
                                    Easing.OutCubic
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 250
                            }
                        }
                    }
                }

                Row {
                    id: statRow

                    width: parent.width
                    height: 44

                    spacing: 6

                    Repeater {
                        model: 4

                        delegate: Rectangle {
                            width:
                                (
                                    statRow.width - 18
                                ) / 4

                            height: 44

                            radius: 8

                            color:
                                root.cardColor

                            Column {
                                anchors.left:
                                    parent.left

                                anchors.right:
                                    parent.right

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing: 4

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        "POWER",
                                        "VOLT",
                                        "HEALTH",
                                        "CYCLES"
                                    ][index]

                                    color:
                                        root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 8

                                    font.weight:
                                        Font.DemiBold
                                }

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        root.powerText,
                                        root.voltageText,
                                        root.healthText,
                                        root.cyclesText
                                    ][index]

                                    color: [
                                        root.stateColor,
                                        root.infoColor,
                                        root.healthColor(
                                            root.healthText
                                        ),
                                        root.cyclesColor(
                                            root.cyclesText
                                        )
                                    ][index]

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 11

                                    font.weight:
                                        Font.Bold

                                    elide:
                                        Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Row {
                    id: extraStatRow

                    width: parent.width
                    height: 44

                    spacing: 6

                    Repeater {
                        model: 2

                        delegate: Rectangle {
                            width:
                                (
                                    extraStatRow.width - 6
                                ) / 2

                            height: 44

                            radius: 8

                            color:
                                root.cardColor

                            Column {
                                anchors.left:
                                    parent.left

                                anchors.right:
                                    parent.right

                                anchors.verticalCenter:
                                    parent.verticalCenter

                                spacing: 4

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        "CURRENT",
                                        "WEAR"
                                    ][index]

                                    color:
                                        root.mutedColor

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 8

                                    font.weight:
                                        Font.DemiBold
                                }

                                Text {
                                    width:
                                        parent.width

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    text: [
                                        root.currentText,
                                        root.wearText
                                    ][index]

                                    color: [
                                        root.infoColor,
                                        root.wearColor(
                                            root.wearText
                                        )
                                    ][index]

                                    font.family:
                                        root.fontName

                                    font.pixelSize: 11

                                    font.weight:
                                        Font.Bold

                                    elide:
                                        Text.ElideRight
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

                Column {
                    width: parent.width

                    spacing: 5

                    Row {
                        width: parent.width
                        height: 18

                        spacing: 8

                        Text {
                            width: 100

                            text: "MODEL"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 8

                            font.weight:
                                Font.DemiBold
                        }

                        Text {
                            width:
                                parent.width - 108

                            text:
                                root.modelText

                            color:
                                root.textColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
                        }
                    }

                    Row {
                        width: parent.width
                        height: 18

                        spacing: 8

                        Text {
                            width: 100

                            text: "MANUFACTURER"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 8

                            font.weight:
                                Font.DemiBold
                        }

                        Text {
                            width:
                                parent.width - 108

                            text:
                                root.manufacturerText

                            color:
                                root.textColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
                        }
                    }

                    Row {
                        width: parent.width
                        height: 18

                        spacing: 8

                        Text {
                            width: 100

                            text: "TECHNOLOGY"

                            color:
                                root.mutedColor

                            font.family:
                                root.fontName

                            font.pixelSize: 8

                            font.weight:
                                Font.DemiBold
                        }

                        Text {
                            width:
                                parent.width - 108

                            text:
                                root.technologyText

                            color:
                                root.textColor

                            font.family:
                                root.fontName

                            font.pixelSize: 10

                            font.weight:
                                Font.DemiBold

                            elide:
                                Text.ElideRight
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
                    height: 44

                    spacing: 6

                    Rectangle {
                        width:
                            (parent.width - 6) / 2

                        height: 44

                        radius: 8

                        color:
                            root.cardColor

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8

                            spacing: 3

                            Text {
                                text:
                                    "FULL CAPACITY"

                                color:
                                    root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 7

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.fullCapacityText

                                color:
                                    root.textColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.Bold

                                elide:
                                    Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width:
                            (parent.width - 6) / 2

                        height: 44

                        radius: 8

                        color:
                            root.cardColor

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8

                            spacing: 3

                            Text {
                                text:
                                    "DESIGN CAPACITY"

                                color:
                                    root.mutedColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 7

                                font.weight:
                                    Font.DemiBold
                            }

                            Text {
                                text:
                                    root.designCapacityText

                                color:
                                    root.textColor

                                font.family:
                                    root.fontName

                                font.pixelSize: 10

                                font.weight:
                                    Font.Bold

                                elide:
                                    Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    height: 18

                    spacing: 8

                    GlowText {
                        glowColor: root.stateColor
                        period: 2500
                        delay: 260
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text:
                            root.isCharging
                            ? "󰂄"
                            : "󰥔"

                        color:
                            root.stateColor

                        font.family:
                            root.fontName

                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter:
                            parent.verticalCenter

                        text:
                            root.timeText

                        color:
                            root.textColor

                        font.family:
                            root.fontName

                        font.pixelSize: 10

                        font.weight:
                            Font.DemiBold
                    }
                }
            }
        }
    }

    Timer {
        id: refreshTimer

        interval: 3000
        repeat: true
        running: true

        onTriggered: {
            root.loadBattery()
        }
    }

    Timer {
        id: closeTimer

        interval: 5000
        repeat: false
        running: true

        onTriggered: {
            if (root.autoClose)
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
        id: batteryProcess

        command: [
            "bash",
            "-c",
            "b=''; for d in /sys/class/power_supply/*; do if [ -f \"$d/type\" ] && [ \"$(cat \"$d/type\" 2>/dev/null)\" = 'Battery' ]; then b=\"$d\"; break; fi; done; if [ -z \"$b\" ]; then printf '%s\\n' 'FOUND=0'; exit 0; fi; readv(){ cat \"$b/$1\" 2>/dev/null; }; status=$(readv status); capacity=$(readv capacity); cycles=$(readv cycle_count); technology=$(readv technology); model=$(readv model_name); manufacturer=$(readv manufacturer); voltage=$(readv voltage_now); power=$(readv power_now); current=$(readv current_now); energy_now=$(readv energy_now); energy_full=$(readv energy_full); energy_design=$(readv energy_full_design); charge_now=$(readv charge_now); charge_full=$(readv charge_full); charge_design=$(readv charge_full_design); [ -n \"$energy_now\" ] || energy_now=\"$charge_now\"; [ -n \"$energy_full\" ] || energy_full=\"$charge_full\"; [ -n \"$energy_design\" ] || energy_design=\"$charge_design\"; if [ -z \"$power\" ] && [ -n \"$current\" ] && [ -n \"$voltage\" ]; then power=$((current * voltage / 1000000)); fi; if [ -n \"$voltage\" ]; then voltage_text=$(awk -v v=\"$voltage\" 'BEGIN {printf \"%.2f V\", v/1000000}'); else voltage_text='N/A'; fi; if [ -n \"$power\" ] && [ \"$power\" -gt 0 ] 2>/dev/null; then power_text=$(awk -v p=\"$power\" 'BEGIN {printf \"%.2f W\", p/1000000}'); else power_text='0.00 W'; fi; if [ -n \"$current\" ] && [ \"$current\" -gt 0 ] 2>/dev/null; then current_text=$(awk -v c=\"$current\" 'BEGIN {printf \"%.2f A\", c/1000000}'); else current_text='0.00 A'; fi; if [ -n \"$energy_full\" ] && [ -n \"$energy_design\" ] && [ \"$energy_design\" -gt 0 ] 2>/dev/null; then health=\"$((energy_full * 100 / energy_design))%\"; wear=$((100 - energy_full * 100 / energy_design)); wear_text=\"${wear}%\"; else health='N/A'; wear_text='N/A'; fi; if [ -n \"$energy_full\" ] && [ \"$energy_full\" -gt 0 ] 2>/dev/null; then full_capacity=$(awk -v e=\"$energy_full\" 'BEGIN {printf \"%.2f Wh\", e/1000000}'); elif [ -n \"$charge_full\" ] && [ -n \"$voltage\" ]; then full_capacity=$(awk -v c=\"$charge_full\" -v v=\"$voltage\" 'BEGIN {printf \"%.2f Wh\", (c*v)/1000000000000}'); else full_capacity='N/A'; fi; if [ -n \"$energy_design\" ] && [ \"$energy_design\" -gt 0 ] 2>/dev/null; then design_capacity=$(awk -v e=\"$energy_design\" 'BEGIN {printf \"%.2f Wh\", e/1000000}'); elif [ -n \"$charge_design\" ] && [ -n \"$voltage\" ]; then design_capacity=$(awk -v c=\"$charge_design\" -v v=\"$voltage\" 'BEGIN {printf \"%.2f Wh\", (c*v)/1000000000000}'); else design_capacity='N/A'; fi; time_text='Time unavailable'; if [ -n \"$power\" ] && [ \"$power\" -gt 0 ] 2>/dev/null && [ -n \"$energy_now\" ]; then if [ \"$status\" = 'Discharging' ]; then minutes=$((energy_now * 60 / power)); time_text=\"$((minutes / 60))h $((minutes % 60))m left\"; elif [ \"$status\" = 'Charging' ] && [ -n \"$energy_full\" ]; then minutes=$(((energy_full - energy_now) * 60 / power)); [ \"$minutes\" -lt 0 ] && minutes=0; time_text=\"$((minutes / 60))h $((minutes % 60))m to full\"; fi; fi; printf '%s\\n' 'FOUND=1' \"STATUS=${status:-Unknown}\" \"CAPACITY=${capacity:-N/A}\" \"TIME=$time_text\" \"POWER=$power_text\" \"VOLTAGE=$voltage_text\" \"CURRENT=$current_text\" \"HEALTH=$health\" \"WEAR=$wear_text\" \"CYCLES=${cycles:-N/A}\" \"TECHNOLOGY=${technology:-N/A}\" \"MODEL=${model:-N/A}\" \"MANUFACTURER=${manufacturer:-N/A}\" \"FULL_CAPACITY=$full_capacity\" \"DESIGN_CAPACITY=$design_capacity\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBattery(this.text)
            }
        }
    }

    Component.onCompleted: {
        root.loadTheme()
        root.loadBattery()
    }
}