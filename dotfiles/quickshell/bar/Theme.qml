pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string configHome:
        Quickshell.env("XDG_CONFIG_HOME") ||
        (Quickshell.env("HOME") + "/.config")

    readonly property string font: "JetBrainsMono Nerd Font"

    property color bg: "#1b1b1b"
    property color fg: "#e0e0e0"
    property color subtext: "#a8a8a8"
    property color muted: "#777777"
    property color accent: "#4a4a4a"
    property color accentAlt: "#8a8a8a"
    property color blue: "#9a9a9a"
    property color cyan: "#8f8f8f"
    property color green: "#81AA99"
    property color red: "#B2729E"
    property color yellow: "#AA978B"

    property bool glassOn: false
    property real glassPct: 50
    property string cavaPos: "center"

    readonly property real barAlpha:
        root.glassOn ? Math.max(0.2, Math.min(1, root.glassPct / 100)) : 0.88

    readonly property color panel: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, root.barAlpha)
    readonly property color accentAltAlpha: Qt.rgba(root.accentAlt.r, root.accentAlt.g, root.accentAlt.b, 0.85)
    readonly property color accentAltHover: Qt.rgba(root.accentAlt.r, root.accentAlt.g, root.accentAlt.b, 0.45)

    function readColor(text, key, fallback) {
        var m = new RegExp("^\\s*" + key + "\\s*=\\s*(#[0-9a-fA-F]{6})", "m").exec(text)
        return m ? m[1] : fallback
    }

    function applyTheme(text) {
        root.bg = root.readColor(text, "background", "#1b1b1b")
        root.fg = root.readColor(text, "foreground", "#e0e0e0")
        root.subtext = root.readColor(text, "subtext", "#a8a8a8")
        root.muted = root.readColor(text, "muted", "#777777")
        root.accent = root.readColor(text, "accent", "#4a4a4a")
        root.accentAlt = root.readColor(text, "accent_alt", "#8a8a8a")
        root.blue = root.readColor(text, "blue", "#9a9a9a")
        root.cyan = root.readColor(text, "cyan", "#8f8f8f")
        root.green = root.readColor(text, "green", "#81AA99")
        root.red = root.readColor(text, "red", "#B2729E")
        root.yellow = root.readColor(text, "yellow", "#AA978B")
    }

    FileView {
        id: themeFile
        path: root.configHome + "/theme/theme.conf"
        onLoaded: root.applyTheme(themeFile.text())
    }

    FileView {
        id: glassFile
        path: root.configHome + "/mycfg/bar-glass"
        printErrors: false
        onLoaded: {
            var l = glassFile.text().split("\n")
            var p = parseFloat(l[1])
            root.glassPct = isNaN(p) ? 50 : p
            root.glassOn = l[0].trim() === "on"
        }
        onLoadFailed: root.glassOn = false
    }

    FileView {
        id: envFile
        path: root.configHome + "/mycfg/doiz-settings.env"
        printErrors: false
        onLoaded: {
            var m = /^cava_pos=(\S+)/m.exec(envFile.text())
            root.cavaPos = m ? m[1] : "center"
        }
        onLoadFailed: root.cavaPos = "center"
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            themeFile.reload()
            glassFile.reload()
            envFile.reload()
        }
    }
}
