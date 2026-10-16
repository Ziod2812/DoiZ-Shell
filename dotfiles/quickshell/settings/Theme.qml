pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property real glassA: 1.0
    property color panelColor: Qt.rgba(basePanelColor.r, basePanelColor.g, basePanelColor.b, Math.min(basePanelColor.a, root.glassA))
    property color cardColor: Qt.rgba(baseCardColor.r, baseCardColor.g, baseCardColor.b, Math.min(baseCardColor.a, root.glassA))
    property color hoverColor: Qt.rgba(baseHoverColor.r, baseHoverColor.g, baseHoverColor.b, Math.min(baseHoverColor.a, root.glassA))
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

    readonly property string home: Quickshell.env("HOME")

    readonly property string configHome:
        Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")

    readonly property string themeFile: root.configHome + "/theme/theme.conf"
    readonly property string dir: Quickshell.shellDir !== "" ? Quickshell.shellDir : root.configHome + "/quickshell/settings"
    readonly property string netScript: root.dir + "/../network/iwd.py"
    readonly property string setScript: root.configHome + "/hypr/scripts/doiz-set"
    readonly property string fontName: "JetBrainsMono Nerd Font"

    readonly property var pages: [
        { key: "system", title: "System", icon: "\uDB81\uDC93", file: "PageSystem.qml" },
        { key: "audio", title: "Audio", icon: "\uDB81\uDD7E", file: "PageAudio.qml" },
        { key: "display", title: "Display", icon: "\uDB80\uDF79", file: "PageDisplay.qml" },
        { key: "battery", title: "Battery", icon: "\uDB80\uDC79", file: "PagePower.qml" },
        { key: "lock", title: "Lock & Idle", icon: "\uDB80\uDF3E", file: "PageLock.qml" },
        { key: "network", title: "Network", icon: "\uDB81\uDDA9", file: "PageNetwork.qml" },
        { key: "bluetooth", title: "Bluetooth", icon: "\uDB80\uDCAF", file: "PageBluetooth.qml" },
        { key: "storage", title: "Storage", icon: "\uDB80\uDECA", file: "PageStorage.qml" },
        { key: "appearance", title: "Appearance", icon: "\uDB80\uDFD8", file: "PageAppearance.qml" },
        { key: "notifications", title: "Notifications", icon: "\uDB80\uDC9A", file: "PageNotifications.qml" },
        { key: "input", title: "Input", icon: "\uDB80\uDF0C", file: "PageInput.qml" },
        { key: "hyprland", title: "Apps & Hyprland", icon: "\uDB80\uDC3B", file: "PageHyprland.qml" },
        { key: "packages", title: "Packages", icon: "\uDB80\uDCD6", file: "PagePackages.qml" },
        { key: "configs", title: "Configs", icon: "\uDB80\uDE14", file: "PageConfigs.qml" }
    ]

    property color basePanelColor: "#f51b1b1b"
    property color baseCardColor: "#942a2a2a"
    property color baseHoverColor: "#b8383838"
    property color lineColor: "#4d777777"
    property color titleColor: "#e0e0e0"
    property color textColor: "#a8a8a8"
    property color mutedColor: "#777777"
    property color accentColor: "#8a8a8a"
    property color goodColor: "#81aa99"
    property color warnColor: "#aa978b"
    property color badColor: "#b2729e"
    property color infoColor: "#9a9a9a"
    property color inkColor: "#1b1b1b"
    property color baseTrackColor: "#cc383838"
    property color orangeColor: "#c08a6a"
    property color stateColor: root.accentColor
    property bool typing: false

    readonly property color toneB: Qt.lighter(root.accentColor, 1.3)
    property real beat: 0.15

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation { target: root; property: "beat"; to: 1; duration: 1300; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "beat"; to: 0.15; duration: 1300; easing.type: Easing.InOutSine }
    }
    property bool picking: false

    function run(args) {
        Quickshell.execDetached(["python3", root.setScript].concat(args))
    }

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function apply(data) {
        var lines = data.split("\n")
        var c = {}
        var inColors = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line === "[colors]") {
                inColors = true
                continue
            }

            if (line.indexOf("[") === 0) {
                inColors = false
                continue
            }

            if (!inColors)
                continue

            var sep = line.indexOf("=")

            if (sep < 0)
                continue

            c[line.substring(0, sep).trim()] = line.substring(sep + 1).trim()
        }

        function pick(key, fallback) {
            var t = c[key] || ""

            if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(t))
                return t

            return fallback
        }

        var bg = Qt.color(pick("background", "#1b1b1b"))
        var sf = Qt.color(pick("surface", "#2a2a2a"))
        var sa = Qt.color(pick("surface_alt", "#383838"))
        var mu = Qt.color(pick("muted", "#777777"))

        root.basePanelColor = Qt.rgba(bg.r, bg.g, bg.b, 0.96)
        root.baseCardColor = Qt.rgba(sf.r, sf.g, sf.b, 0.92)
        root.baseHoverColor = Qt.rgba(sa.r, sa.g, sa.b, 0.72)
        root.lineColor = Qt.rgba(mu.r, mu.g, mu.b, 0.3)
        root.inkColor = bg
        root.baseTrackColor = Qt.rgba(sa.r, sa.g, sa.b, 0.8)

        root.titleColor = pick("foreground", "#e0e0e0")
        root.textColor = pick("subtext", "#a8a8a8")
        root.mutedColor = pick("muted", "#777777")
        root.accentColor = pick("accent_alt", "#8a8a8a")
        root.goodColor = pick("green", "#81AA99")
        root.warnColor = pick("yellow", "#AA978B")
        root.badColor = pick("red", "#B2729E")
        root.infoColor = pick("blue", "#9a9a9a")
        root.orangeColor = pick("orange", root.warnColor)
    }

    Process {
        id: themeProcess

        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "doiz", root.themeFile]

        stdout: StdioCollector {
            onStreamFinished: root.apply(this.text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!themeProcess.running)
                themeProcess.running = true
        }
    }
}
