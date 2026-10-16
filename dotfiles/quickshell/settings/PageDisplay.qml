import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property int level: -1
    property string device: "--"
    property string current: "--"
    property string maximum: "--"
    property int pending: -1
    property bool checked: false

    readonly property bool available: page.level >= 0

    ListModel {
        id: monitorModel
    }

    function icon() {
        if (page.level < 25)
            return "\uDB80\uDCDD"

        if (page.level < 50)
            return "\uDB80\uDCDE"

        if (page.level < 75)
            return "\uDB80\uDCDF"

        return "\uDB80\uDCE0"
    }

    function label() {
        if (!page.available)
            return page.checked ? "No backlight" : "Checking..."

        if (page.level >= 75)
            return "Bright"

        if (page.level >= 50)
            return "Comfortable"

        if (page.level >= 25)
            return "Medium"

        return "Dim"
    }

    function parseBrightness(text) {
        var p = text.trim().split(",")

        page.checked = true

        if (p.length < 5) {
            page.level = -1
            return
        }

        var pct = parseInt(p[3])

        if (!brightnessApply.running && !isNaN(pct))
            page.level = pct

        page.device = p[0] || "--"
        page.current = p[2] || "--"
        page.maximum = p[4] || "--"
    }

    function setLevel(v) {
        var n = Math.max(1, Math.min(100, Math.round(v)))
        page.level = n
        page.pending = n
        brightnessApply.restart()
    }

    function parseMonitors(text) {
        var data = []

        try {
            data = JSON.parse(text)
        } catch (e) {
            data = []
        }

        monitorModel.clear()

        for (var i = 0; i < data.length; i++) {
            var m = data[i]

            monitorModel.append({
                name: m.name || "--",
                desc: m.description || ((m.make || "") + " " + (m.model || "")).trim(),
                mode: m.width + "x" + m.height + " @ " + Math.round(m.refreshRate) + " Hz",
                scl: "x" + m.scale,
                pos: m.x + "," + m.y,
                focused: m.focused === true
            })
        }
    }

    function refresh() {
        if (!brightnessProc.running)
            brightnessProc.running = true

        if (!monitorProc.running)
            monitorProc.running = true
    }

    readonly property bool hasHero: true

    readonly property color tone: page.available ? Theme.warnColor : Theme.mutedColor

    Binding {
        target: Theme
        property: "stateColor"
        value: page.tone
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => {
            if (page.available)
                page.setLevel(page.level + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
    }

    Column {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Hero {
            width: parent.width
            icon: page.icon()
            title: "BRIGHTNESS"
            subtitle: page.label()
            badge: page.available ? page.level + "%" : "--"
            value: Math.max(0, page.level)
            tone: page.tone
            interactive: page.available
            knob: true

            onMoved: (v) => page.setLevel(v)
        }

        Ctl {
            width: parent.width
            enabled: page.available
            showMiddle: false
            tone: page.tone

            onMinus: page.setLevel(page.level - 5)
            onPlus: page.setLevel(page.level + 5)
        }

        Row {
            width: parent.width
            spacing: 6

            Stat {
                width: (parent.width - 12) / 3
                label: "LEVEL"
                value: page.available ? page.level + "%" : "--"
                tone: page.tone
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "CURRENT"
                value: page.current
                tone: Theme.accentColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "MAX"
                value: page.maximum
                tone: Theme.accentColor
            }
        }

        Card {
            width: parent.width
            height: 44

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    text: "DEVICE"
                    color: Theme.mutedColor
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    text: page.device
                    color: Theme.accentColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        Head {
            width: parent.width
            title: "MONITORS"
            info: monitorModel.count
        }
    }

    ListView {
        id: monitorList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom

        model: monitorModel
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Card {
            id: mon

            required property string name
            required property string desc
            required property string mode
            required property string scl
            required property string pos
            required property bool focused

            width: monitorList.width
            height: 52
            selected: mon.focused
            tone: Theme.infoColor

            Lbl {
                id: monIcon

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "\uDB80\uDF79"
                color: mon.focused ? Theme.infoColor : Theme.mutedColor
                font.pixelSize: 20
            }

            Column {
                anchors.left: monIcon.right
                anchors.leftMargin: 12
                anchors.right: modeText.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Lbl {
                    width: parent.width
                    text: mon.name
                    color: Theme.titleColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Lbl {
                    width: parent.width
                    text: mon.desc
                    color: Theme.mutedColor
                    font.pixelSize: 9
                }
            }

            Column {
                id: modeText

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Lbl {
                    anchors.right: parent.right
                    text: mon.mode
                    color: Theme.titleColor
                    font.pixelSize: 10
                }

                Lbl {
                    anchors.right: parent.right
                    text: "scale " + mon.scl + "  pos " + mon.pos
                    color: Theme.mutedColor
                    font.pixelSize: 9
                }
            }
        }
    }

    Process {
        id: brightnessProc

        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -n1"]

        stdout: StdioCollector {
            onStreamFinished: page.parseBrightness(this.text)
        }
    }

    Process {
        id: monitorProc

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: page.parseMonitors(this.text)
        }
    }

    Timer {
        id: brightnessApply

        interval: 40

        onTriggered: Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", page.pending + "%"])
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: page.refresh()
    }
}
