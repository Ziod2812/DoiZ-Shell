import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property bool powered: true
    property bool scanning: false
    property string busyMac: ""
    property string statusText: "Loading..."

    property int connectedCount: 0

    readonly property color statusColor:
        !page.powered
        ? Theme.mutedColor
        : page.busyMac !== ""
          ? Theme.warnColor
          : page.scanning
            ? Theme.accentColor
            : page.connectedCount > 0
              ? Theme.infoColor
              : Theme.mutedColor

    readonly property bool hasHero: true

    Binding {
        target: Theme
        property: "stateColor"
        value: page.statusColor
    }

    ListModel {
        id: deviceModel
    }

    function updateStatus() {
        if (!page.powered)
            page.statusText = "Bluetooth is off"
        else if (page.busyMac !== "")
            page.statusText = "Working..."
        else if (page.scanning)
            page.statusText = "Scanning..."
        else if (page.connectedCount > 0)
            page.statusText = page.connectedCount + " connected"
        else
            page.statusText = "No device connected"
    }

    function parseDevices(text) {
        var lines = text.trim().split("\n")
        var rows = []

        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("|")

            if (p.length < 4)
                continue

            rows.push({
                mac: p[0],
                connected: p[1] === "yes",
                paired: p[2] === "yes",
                name: p.slice(3).join("|")
            })
        }

        var online = 0

        for (var c = 0; c < rows.length; c++) {
            if (rows[c].connected)
                online++
        }

        page.connectedCount = online

        rows.sort(function(a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1

            if (a.paired !== b.paired)
                return a.paired ? -1 : 1

            return a.name.localeCompare(b.name)
        })

        var same = deviceModel.count === rows.length

        if (same) {
            for (var j = 0; j < rows.length; j++) {
                if (deviceModel.get(j).mac !== rows[j].mac) {
                    same = false
                    break
                }
            }
        }

        if (same) {
            for (var k = 0; k < rows.length; k++)
                deviceModel.set(k, rows[k])
        } else {
            deviceModel.clear()

            for (var n = 0; n < rows.length; n++)
                deviceModel.append(rows[n])
        }

        page.updateStatus()
    }

    function refresh() {
        if (!stateProc.running)
            stateProc.running = true

        if (page.powered && !listProc.running)
            listProc.running = true
    }

    function act(action, mac) {
        if (actProc.running)
            return

        page.busyMac = mac
        page.updateStatus()
        actProc.command = ["bash", Theme.dir + "/bluetooth.sh", action, mac]
        actProc.running = true
    }

    function pick(device) {
        if (device.connected)
            page.act("disconnect", device.mac)
        else if (device.paired)
            page.act("connect", device.mac)
        else
            page.act("pair", device.mac)
    }

    Row {
        id: topRow

        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        spacing: 10

        Btn {
            width: 40
            height: 40
            iconSize: 21
            filled: page.powered
            icon: page.powered ? "\uDB80\uDCAF" : "\uDB80\uDCB2"
            tone: page.statusColor

            onClicked: toggleProc.running = true
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 114
            spacing: 2

            Lbl {
                text: "BLUETOOTH"
                color: Theme.titleColor
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Lbl {
                width: parent.width
                text: page.statusText
                color: page.statusColor
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Btn {
            width: 54
            height: 40
            icon: "\uDB81\uDC50"
            tone: page.scanning ? Theme.accentColor : Theme.textColor
            enabled: page.powered && !page.scanning

            onClicked: {
                page.scanning = true
                page.updateStatus()
                scanProc.running = true
            }
        }
    }

    Rectangle {
        id: line

        anchors.top: topRow.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 1
        color: Theme.tint(page.statusColor, 0.35)
    }

    Head {
        id: head

        anchors.top: line.bottom
        anchors.topMargin: 8
        width: parent.width
        title: "DEVICES"
        info: deviceModel.count
    }

    ListView {
        id: deviceList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom

        model: page.powered ? deviceModel : null
        spacing: 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded

            contentItem: Rectangle {
                implicitWidth: 3
                radius: 2
                visible: parent && parent.size < 1
                color: Theme.accentColor
                opacity: 0.55
            }
        }

        delegate: Card {
            id: dev

            required property string mac
            required property bool connected
            required property bool paired
            required property string name

            readonly property bool busy: page.busyMac === dev.mac

            readonly property color stateColor:
                dev.busy
                ? Theme.warnColor
                : dev.connected
                  ? Theme.infoColor
                  : dev.paired
                    ? Theme.textColor
                    : Theme.mutedColor

            width: deviceList.width
            height: 54
            clickable: true
            selected: dev.connected || dev.busy
            tone: dev.stateColor

            onClicked: page.pick({ mac: dev.mac, connected: dev.connected, paired: dev.paired })

            Rectangle {
                id: tile

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 4
                color: Theme.tint(dev.stateColor, 0.16)

                Lbl {
                    anchors.centerIn: parent
                    text: dev.connected ? "\uDB80\uDCB1" : "\uDB80\uDCAF"
                    color: dev.stateColor
                    font.pixelSize: 18
                }
            }

            Column {
                anchors.left: tile.right
                anchors.leftMargin: 10
                anchors.right: stateText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Lbl {
                    width: parent.width
                    text: dev.name
                    color: Theme.titleColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Lbl {
                    width: parent.width
                    text: dev.mac
                    color: Theme.mutedColor
                    font.pixelSize: 9
                }
            }

            Lbl {
                id: stateText

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: dev.stateColor

                text: dev.busy
                      ? "Working..."
                      : dev.connected
                        ? "Connected"
                        : dev.paired
                          ? "Paired"
                          : "Pair"
            }
        }
    }

    Card {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        height: 84
        visible: !page.powered || deviceModel.count === 0

        Column {
            anchors.centerIn: parent
            spacing: 6

            Lbl {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.powered ? "\uDB80\uDCAF" : "\uDB80\uDCB2"
                color: Theme.warnColor
                font.pixelSize: 22
            }

            Lbl {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.powered ? "No devices - press scan" : "Bluetooth is off"
                color: Theme.warnColor
                font.pixelSize: 10
            }
        }
    }

    Process {
        id: stateProc

        command: ["bash", Theme.dir + "/bluetooth.sh", "state"]

        stdout: StdioCollector {
            onStreamFinished: {
                page.powered = this.text.trim() === "enabled"
                page.updateStatus()
            }
        }
    }

    Process {
        id: listProc

        command: ["bash", Theme.dir + "/bluetooth.sh", "list"]

        stdout: StdioCollector {
            onStreamFinished: page.parseDevices(this.text)
        }
    }

    Process {
        id: toggleProc

        command: ["bash", Theme.dir + "/bluetooth.sh", "toggle"]

        onExited: refreshTimer.restart()
    }

    Process {
        id: scanProc

        command: ["bash", Theme.dir + "/bluetooth.sh", "scan"]

        onExited: {
            page.scanning = false
            page.refresh()
        }
    }

    Process {
        id: actProc

        command: []

        onExited: {
            page.busyMac = ""
            page.refresh()
        }
    }

    Timer {
        id: refreshTimer

        interval: 600

        onTriggered: page.refresh()
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: page.refresh()
    }
}
