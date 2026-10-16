import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property int volume: 0
    property bool muted: false
    property int micVolume: 0
    property bool micMuted: false
    property string deviceId: ""
    property int pendingOut: -1
    property int pendingIn: -1

    ListModel {
        id: sinkModel
    }

    function parseVolume(text) {
        var m = /Volume:\s+([0-9.]+)/.exec(text)

        return {
            value: m ? Math.round(parseFloat(m[1]) * 100) : -1,
            muted: text.indexOf("[MUTED]") !== -1
        }
    }

    function volumeIcon(v, muted) {
        if (muted || v <= 0)
            return "\uDB81\uDD81"

        if (v < 35)
            return "\uDB81\uDD7F"

        if (v < 70)
            return "\uDB81\uDD80"

        return "\uDB81\uDD7E"
    }

    function refresh() {
        if (!outProc.running)
            outProc.running = true

        if (!inProc.running)
            inProc.running = true

        if (!sinkProc.running)
            sinkProc.running = true
    }

    function setOut(v) {
        var n = Math.max(0, Math.min(100, Math.round(v)))
        page.volume = n
        page.pendingOut = n
        applyOut.restart()
    }

    function setIn(v) {
        var n = Math.max(0, Math.min(100, Math.round(v)))
        page.micVolume = n
        page.pendingIn = n
        applyIn.restart()
    }

    function syncSinks(text) {
        var lines = text.trim().split("\n")
        var rows = []

        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("\t")

            if (p.length < 3 || !/^[0-9]+$/.test(p[0].trim()))
                continue

            rows.push({ devId: p[0].trim(), name: p[1].trim(), isDefault: p[2].trim() === "1" })

            if (p[2].trim() === "1")
                page.deviceId = p[0].trim()
        }

        sinkModel.clear()

        for (var k = 0; k < rows.length; k++)
            sinkModel.append(rows[k])
    }

    readonly property bool hasHero: true

    Binding {
        target: Theme
        property: "stateColor"
        value: page.muted ? Theme.badColor : Theme.accentColor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: (wheel) => page.setOut(page.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
    }

    Column {
        id: top

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Hero {
            width: parent.width
            icon: page.volumeIcon(page.volume, page.muted)
            title: "VOLUME"
            subtitle: page.muted ? "Muted" : sinkModel.count > 0 ? sinkModel.get(0).name : "Default output"
            badge: page.volume + "%"
            value: page.volume
            tone: page.muted ? Theme.badColor : Theme.accentColor

            onMoved: (v) => page.setOut(v)
        }

        Ctl {
            width: parent.width
            tone: Theme.accentColor
            middleIcon: page.muted ? "\uDB81\uDD81" : "\uDB81\uDD7E"
            middleTone: page.muted ? Theme.badColor : Theme.accentColor
            middleActive: page.muted

            onMinus: page.setOut(page.volume - 5)
            onPlus: page.setOut(page.volume + 5)

            onMiddle: {
                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                refreshTimer.restart()
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineColor
        }

        Hero {
            width: parent.width
            icon: page.micMuted ? "\uDB80\uDF6D" : "\uDB80\uDF6C"
            title: "MICROPHONE"
            subtitle: page.micMuted ? "Muted" : "Default input"
            badge: page.micVolume + "%"
            value: page.micVolume
            tone: page.micMuted ? Theme.badColor : Theme.infoColor

            onMoved: (v) => page.setIn(v)
        }

        Ctl {
            width: parent.width
            tone: Theme.infoColor
            middleIcon: page.micMuted ? "\uDB80\uDF6D" : "\uDB80\uDF6C"
            middleTone: page.micMuted ? Theme.badColor : Theme.infoColor
            middleActive: page.micMuted

            onMinus: page.setIn(page.micVolume - 5)
            onPlus: page.setIn(page.micVolume + 5)

            onMiddle: {
                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                refreshTimer.restart()
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.lineColor
        }

        Head {
            width: parent.width
            title: "OUTPUT DEVICES"
            info: sinkModel.count
        }
    }

    ListView {
        id: sinkList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom

        model: sinkModel
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Card {
            id: row

            required property string devId
            required property string name
            required property bool isDefault

            width: sinkList.width
            height: 44
            clickable: true
            selected: row.isDefault
            tone: Theme.accentColor

            onClicked: {
                page.deviceId = row.devId
                Quickshell.execDetached(["wpctl", "set-default", row.devId])
                refreshTimer.restart()
            }

            Lbl {
                id: spk

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "\uDB81\uDCC3"
                color: row.isDefault ? Theme.accentColor : Theme.mutedColor
                font.pixelSize: 16
            }

            Lbl {
                anchors.left: spk.right
                anchors.leftMargin: 12
                anchors.right: mark.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: row.name
                color: Theme.titleColor
                font.pixelSize: 11
            }

            Lbl {
                id: mark

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: row.isDefault
                text: "\uDB80\uDD2C"
                color: Theme.accentColor
                font.pixelSize: 14
            }
        }
    }

    Process {
        id: outProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                var r = page.parseVolume(this.text)

                if (r.value >= 0 && !applyOut.running)
                    page.volume = Math.min(100, r.value)

                page.muted = r.muted
            }
        }
    }

    Process {
        id: inProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: StdioCollector {
            onStreamFinished: {
                var r = page.parseVolume(this.text)

                if (r.value >= 0 && !applyIn.running)
                    page.micVolume = Math.min(100, r.value)

                page.micMuted = r.muted
            }
        }
    }

    Process {
        id: sinkProc

        command: ["sh", Theme.dir + "/audio.sh", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: page.syncSinks(this.text)
        }
    }

    Timer {
        id: applyOut

        interval: 40

        onTriggered: Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", page.pendingOut + "%"])
    }

    Timer {
        id: applyIn

        interval: 40

        onTriggered: Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", page.pendingIn + "%"])
    }

    Timer {
        id: refreshTimer

        interval: 250

        onTriggered: page.refresh()
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: page.refresh()
    }
}
