import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property bool found: true
    property string status: "--"
    property string levelText: "--"
    property string timeText: "--"
    property string powerText: "--"
    property string voltageText: "--"
    property string currentText: "--"
    property string healthText: "--"
    property string wearText: "--"
    property string cyclesText: "--"
    property string technologyText: "--"
    property string modelText: "--"
    property string makerText: "--"
    property string fullText: "--"
    property string designText: "--"
    property string profile: ""

    readonly property int level: {
        var n = parseInt(page.levelText)
        return isNaN(n) ? -1 : n
    }

    readonly property bool charging: page.status === "Charging"

    readonly property color tone:
        page.charging
        ? Theme.goodColor
        : page.level < 0
          ? Theme.mutedColor
          : page.level <= 20
            ? Theme.badColor
            : page.level <= 50
              ? Theme.warnColor
              : Theme.goodColor

    function icon() {
        if (!page.found || page.level < 0)
            return "\uDB80\uDC91"

        if (page.charging)
            return "\uDB80\uDC84"

        var suffix = [0x83, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x79]

        return "\uDB80" + String.fromCharCode(0xDC00 + suffix[Math.min(10, Math.floor(page.level / 10))])
    }

    function parse(text) {
        var lines = text.trim().split("\n")
        var v = {}

        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].indexOf("=")

            if (s > 0)
                v[lines[i].substring(0, s)] = lines[i].substring(s + 1)
        }

        if (v["FOUND"] === "0") {
            page.found = false
            page.status = "No battery"
            page.timeText = "Battery unavailable"
            return
        }

        page.found = true
        page.status = v["STATUS"] || "Unknown"
        page.levelText = v["CAPACITY"] || "--"
        page.timeText = v["TIME"] || "Time unavailable"
        page.powerText = v["POWER"] || "--"
        page.voltageText = v["VOLTAGE"] || "--"
        page.currentText = v["CURRENT"] || "--"
        page.healthText = v["HEALTH"] || "--"
        page.wearText = v["WEAR"] || "--"
        page.cyclesText = v["CYCLES"] || "--"
        page.technologyText = v["TECHNOLOGY"] || "--"
        page.modelText = v["MODEL"] || "--"
        page.makerText = v["MANUFACTURER"] || "--"
        page.fullText = v["FULL_CAPACITY"] || "--"
        page.designText = v["DESIGN_CAPACITY"] || "--"
    }

    function refresh() {
        if (!batteryProc.running)
            batteryProc.running = true

        if (!profileProc.running)
            profileProc.running = true
    }

    readonly property bool hasHero: true

    readonly property string statusLine:
        page.charging
        ? "Charging  " + page.timeText
        : page.status + "  " + page.timeText

    function healthTone(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return Theme.textColor

        return v >= 80 ? Theme.goodColor : v >= 60 ? Theme.warnColor : v >= 40 ? Theme.orangeColor : Theme.badColor
    }

    function wearTone(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return Theme.textColor

        return v <= 20 ? Theme.goodColor : v <= 40 ? Theme.warnColor : v <= 60 ? Theme.orangeColor : Theme.badColor
    }

    function cyclesTone(text) {
        var v = parseInt(text)

        if (isNaN(v))
            return Theme.textColor

        return v < 300 ? Theme.goodColor : v < 600 ? Theme.warnColor : v < 1000 ? Theme.orangeColor : Theme.badColor
    }

    Binding {
        target: Theme
        property: "stateColor"
        value: page.tone
    }

    Column {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Hero {
            width: parent.width
            icon: page.icon()
            title: "BATTERY"
            subtitle: page.statusLine
            badge: page.level >= 0 ? page.level + "%" : "--"
            value: Math.max(0, page.level)
            tone: page.tone
            interactive: false
        }

        Row {
            width: parent.width
            spacing: 6

            Stat {
                width: (parent.width - 12) / 3
                label: "POWER"
                value: page.powerText
                tone: Theme.infoColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "VOLTAGE"
                value: page.voltageText
                tone: Theme.infoColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "CURRENT"
                value: page.currentText
                tone: Theme.infoColor
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Stat {
                width: (parent.width - 12) / 3
                label: "HEALTH"
                value: page.healthText
                tone: page.healthTone(page.healthText)
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "WEAR"
                value: page.wearText
                tone: page.wearTone(page.wearText)
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "CYCLES"
                value: page.cyclesText
                tone: page.cyclesTone(page.cyclesText)
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Stat {
                width: (parent.width - 12) / 3
                label: "FULL"
                value: page.fullText
                tone: Theme.accentColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "DESIGN"
                value: page.designText
                tone: Theme.accentColor
            }

            Stat {
                width: (parent.width - 12) / 3
                label: "TECH"
                value: page.technologyText
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
                    text: "MODEL"
                    color: Theme.mutedColor
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Lbl {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    text: page.modelText + "  " + page.makerText
                    color: Theme.accentColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        Rectangle {
            visible: page.profile !== ""
            width: parent.width
            height: 1
            color: Theme.lineColor
        }

        Head {
            visible: page.profile !== ""
            width: parent.width
            title: "POWER PROFILE"
        }

        Row {
            visible: page.profile !== ""
            width: parent.width
            spacing: 6

            Repeater {
                model: [
                    { label: "PERFORMANCE", value: "performance", icon: "\uDB81\uDCC5" },
                    { label: "BALANCED", value: "balanced", icon: "\uDB81\uDDD1" },
                    { label: "POWER SAVER", value: "power-saver", icon: "\uDB80\uDF2A" }
                ]

                delegate: Btn {
                    required property var modelData

                    width: (top.width - 12) / 3
                    height: 44
                    icon: modelData.icon
                    label: modelData.label
                    filled: page.profile === modelData.value
                    tone: page.profile === modelData.value ? page.tone : Theme.textColor

                    onClicked: {
                        page.profile = modelData.value
                        Quickshell.execDetached(["powerprofilesctl", "set", modelData.value])
                    }
                }
            }
        }
    }

    Process {
        id: batteryProc

        command: ["sh", Theme.dir + "/battery.sh"]

        stdout: StdioCollector {
            onStreamFinished: page.parse(this.text)
        }
    }

    Process {
        id: profileProc

        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: page.profile = this.text.trim()
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: page.refresh()
    }
}
