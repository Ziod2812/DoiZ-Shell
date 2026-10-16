import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

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

    readonly property string cfgHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string mono: "JetBrainsMono Nerd Font"

    property bool closing: false
    property var pending: null
    property int selected: -1

    readonly property int cols: 6
    readonly property int btnW: 96
    readonly property int btnH: 84
    readonly property int panelW: actions.length * btnW + (actions.length - 1) * 10 + 32

    property bool canHibernate: false

    readonly property var allActions: [
        { label: "Suspend", glyph: "\uf186", hotkey: "s", cmd: ["systemctl", "suspend"] },
        { label: "Reboot", glyph: "\uf021", hotkey: "r", cmd: ["systemctl", "reboot"] },
        { label: "Shutdown", glyph: "\uf011", hotkey: "p", cmd: ["systemctl", "poweroff"] },
        { label: "Hibernate", glyph: "\uf2dc", hotkey: "h", cmd: ["systemctl", "hibernate"], needsHibernate: true },
        { label: "Lock", glyph: "\uf023", hotkey: "l", cmd: ["loginctl", "lock-session"] },
        { label: "Logout", glyph: "\uf08b", hotkey: "e", cmd: ["hyprctl", "dispatch", "exit"] }
    ]

    readonly property var actions: allActions.filter(function(a) {
        return !a.needsHibernate || root.canHibernate
    })

    Process {
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = /"(yes|challenge)"/.test(this.text)
        }
    }

    function closePopup() {
        if (root.closing)
            return

        root.closing = true
        card.opacity = 0
        card.y = 0
        quitTimer.start()
    }

    function run(index) {
        var a = root.actions[index]

        if (!a)
            return

        root.pending = a.cmd
        root.closePopup()
    }

    function move(dx, dy) {
        var n = root.actions.length

        if (root.selected < 0) {
            root.selected = 0
            return
        }

        var next = root.selected + dx + dy * root.cols

        if (dx !== 0)
            next = (root.selected + dx + n) % n
        else if (next < 0 || next >= n)
            next = root.selected

        root.selected = next
    }

    Timer {
        id: quitTimer

        interval: 180
        onTriggered: {
            if (root.pending)
                Quickshell.execDetached(root.pending)

            Qt.quit()
        }
    }

    IpcHandler {
        target: "popup"

        function close(): void {
            root.closePopup()
        }
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

    HyprlandFocusGrab {
        windows: [ win ]
        active: true

        onCleared: {
            Quickshell.execDetached(["sh", "-c", "date +%s%N > \"${XDG_RUNTIME_DIR:-/tmp}/doiz-popup-closed-$1\"", "doiz", "powermenu"])
            root.closePopup()
        }
    }

    PanelWindow {
        id: win

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: root.panelW + 12
        implicitHeight: pcol.height + 32 + 10 + 10

        WlrLayershell.namespace: "doiz-power-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            id: card

            x: 6
            y: 0
            width: root.panelW
            height: pcol.height + 32
            radius: 12
            color: root.panelColor
            border.width: 1
            border.color: root.tint(root.accentColor, 0.45)
            focus: true
            opacity: 0

            Component.onCompleted: {
                opacity = 1
                y = 10
            }

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 140 }
            }

            GradBorder {
                rr: 12
                c1: root.accentColor
                c2: root.toneB
                c3: root.accentColor
                c4: root.toneB
                cycle: 13000
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closePopup()
                } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.move(-1, 0)
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                    root.move(1, 0)
                } else if (event.key === Qt.Key_Up) {
                    root.move(0, -1)
                } else if (event.key === Qt.Key_Down) {
                    root.move(0, 1)
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.run(root.selected)
                } else {
                    var t = String(event.text).toLowerCase()

                    for (var i = 0; i < root.actions.length; i++) {
                        if (root.actions[i].hotkey === t) {
                            root.run(i)
                            break
                        }
                    }
                }
            }

            Column {
                id: pcol

                x: 16
                y: 16
                width: root.panelW - 32
                spacing: 8

                Row {
                    spacing: 10

                    Repeater {
                        model: root.actions

                        delegate: Item {
                            id: btn

                            readonly property bool active: root.selected === index

                            width: root.btnW
                            height: root.btnH

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: root.cardColor
                                visible: !btn.active
                                border.width: 1
                                border.color: root.lineColor
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                opacity: btn.active ? 1 : 0

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: root.accentColor }
                                    GradientStop { position: 1.0; color: root.toneB }
                                }

                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.glyph
                                    color: btn.active ? root.inkColor : root.titleColor
                                    font.family: root.mono
                                    font.pixelSize: 28
                                    renderType: Text.NativeRendering
                                    scale: btn.active ? 1.1 : 1

                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label
                                    color: btn.active ? root.inkColor : root.textColor
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selected = index
                                onClicked: root.run(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
