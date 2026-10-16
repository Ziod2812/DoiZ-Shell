import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property int barCount: 192

    property bool loaded: false
    property bool enabled: true
    property string pos: "bottom"
    property string shownPos: "bottom"
    property real reveal: 0
    property bool gap: false
    property var levels: []
    property color tip: "#8a8a8a"
    property color base: "#4a4a4a"

    readonly property color toneB: Qt.lighter(root.tip, 1.3)
    readonly property color toneC: Qt.lighter(root.tip, 1.7)

    function waveLevel(n) {
        var x = Math.max(0, Math.min(1, (n || 0) / 100))
        return 1 - Math.pow(1 - x, 2.0)
    }

    function setPos(p) {
        if (p !== "top" && p !== "bottom")
            return
        if (p === root.pos)
            return
        root.pos = p
        swap.restart()
    }

    function readColor(text, key, fallback) {
        var m = new RegExp("^\\s*" + key + "\\s*=\\s*(#[0-9a-fA-F]{6})", "m").exec(text)
        return m ? m[1] : fallback
    }

    function applyEnv(text) {
        var on = /^cava_desk=(\S+)/m.exec(text)
        var p = /^cava_desk_pos=(\S+)/m.exec(text)
        var want = p && p[1] === "top" ? "top" : "bottom"
        root.enabled = !(on && on[1] === "0")
        if (!root.loaded) {
            root.pos = want
            root.shownPos = want
            root.loaded = true
            appear.restart()
        } else {
            root.setPos(want)
        }
    }

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 200
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: {
                root.gap = true
                root.shownPos = root.pos
            }
        }

        PauseAnimation {
            duration: 280
        }

        ScriptAction {
            script: root.gap = false
        }

        NumberAnimation {
            target: root
            property: "reveal"
            to: 1
            duration: 700
            easing.type: Easing.OutQuad
        }
    }

    NumberAnimation {
        id: appear

        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 700
        easing.type: Easing.OutQuad
    }

    FileView {
        id: themeFile

        path: root.cfgHome + "/theme/theme.conf"
        printErrors: false
        onLoaded: {
            root.tip = root.readColor(themeFile.text(), "accent_alt", "#8a8a8a")
            root.base = root.readColor(themeFile.text(), "accent", "#4a4a4a")
        }
    }

    FileView {
        id: envFile

        path: root.cfgHome + "/mycfg/doiz-settings.env"
        printErrors: false
        onLoaded: root.applyEnv(envFile.text())
        onLoadFailed: root.applyEnv("")
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            themeFile.reload()
            envFile.reload()
        }
    }

    IpcHandler {
        target: "cavadesk"

        function pos(p: string): void {
            root.setPos(p)
        }

        function toggle(): void {
            root.setPos(root.pos === "bottom" ? "top" : "bottom")
        }
    }

    Process {
        id: cavaProc

        running: root.enabled
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]

        stdout: SplitParser {
            onRead: data => {
                var p = data.split(";")
                var out = []
                for (var i = 0; i < p.length && out.length < root.barCount; i++) {
                    if (p[i] === "")
                        continue
                    var n = parseInt(p[i])
                    out.push(isNaN(n) ? 0 : Math.max(0, Math.min(100, n)))
                }
                if (out.length > 0)
                    root.levels = out
            }
        }

        onRunningChanged: {
            if (!running && root.enabled)
                cavaRestart.restart()
        }
    }

    Timer {
        id: cavaRestart

        interval: 2000

        onTriggered: cavaProc.running = root.enabled
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            screen: win.modelData
            visible: root.loaded && root.enabled && !root.gap
            color: "transparent"
            implicitHeight: Math.round(win.modelData.height * 0.4)
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            WlrLayershell.namespace: "doiz-cavadesk"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                left: true
                right: true
                top: root.shownPos === "top"
                bottom: root.shownPos === "bottom"
            }

            Item {
                id: stage

                readonly property bool atTop: root.shownPos === "top"

                anchors.fill: parent
                opacity: root.reveal

                transform: Scale {
                    origin.y: stage.height / 2
                    yScale: stage.atTop ? -1 : 1
                }

                Item {
                    id: backWave

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.round(stage.height * 0.85)
                    opacity: 0.85

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 36
                    }

                    Row {
                        id: backRow

                        width: backWave.width
                        height: backWave.height
                        anchors.bottom: parent.bottom
                        spacing: 0

                        Repeater {
                            model: root.barCount

                            delegate: Item {
                                id: bcell

                                required property int index
                                readonly property real v: root.waveLevel(root.levels[bcell.index])

                                width: backWave.width / root.barCount
                                height: backRow.height

                                Rectangle {
                                    width: parent.width + 2
                                    height: Math.max(10, bcell.v * backRow.height)
                                    anchors.bottom: parent.bottom

                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Qt.rgba(root.toneB.r, root.toneB.g, root.toneB.b, 0.0) }
                                        GradientStop { position: 1.0; color: root.tip }
                                    }

                                    Behavior on height { NumberAnimation { duration: 90 } }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: spectrum

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.round(stage.height * 0.6)

                    Row {
                        id: wave

                        width: spectrum.width
                        height: spectrum.height
                        anchors.bottom: parent.bottom
                        spacing: 0

                        Repeater {
                            model: root.barCount

                            delegate: Item {
                                id: cell

                                required property int index
                                readonly property real v: root.waveLevel(root.levels[cell.index])
                                readonly property real h: 3 + Math.round(cell.v * (wave.height - 10) / 3) * 3

                                width: spectrum.width / root.barCount
                                height: wave.height

                                Rectangle {
                                    id: body

                                    width: parent.width + 1
                                    height: cell.h
                                    anchors.bottom: parent.bottom
                                    color: root.tip

                                    Behavior on height { NumberAnimation { duration: 60 } }
                                }

                                Rectangle {
                                    width: parent.width + 1
                                    height: 3
                                    anchors.bottom: body.top
                                    visible: cell.v > 0.04
                                    color: root.toneC
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
