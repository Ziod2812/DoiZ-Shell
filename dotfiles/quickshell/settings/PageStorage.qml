import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    ListModel {
        id: diskModel
    }

    function parse(text) {
        var lines = text.trim().split("\n")
        var rows = []

        for (var i = 0; i < lines.length; i++) {
            var f = lines[i].trim().split(/\s+/)

            if (f.length < 7)
                continue

            rows.push({
                source: f[0],
                fs: f[1],
                size: f[2],
                used: f[3],
                avail: f[4],
                percent: parseInt(f[5]) || 0,
                mount: f.slice(6).join(" ")
            })
        }

        diskModel.clear()

        for (var k = 0; k < rows.length; k++)
            diskModel.append(rows[k])
    }

    function toneFor(p) {
        return p >= 90 ? Theme.badColor : p >= 75 ? Theme.warnColor : Theme.goodColor
    }

    Head {
        id: head

        width: parent.width
        title: "MOUNTED VOLUMES"
        info: diskModel.count
    }

    ListView {
        id: diskList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom

        model: diskModel
        spacing: 8
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
            id: disk

            required property string source
            required property string fs
            required property string size
            required property string used
            required property string avail
            required property int percent
            required property string mount

            width: diskList.width
            height: 76
            clickable: true
            tone: page.toneFor(disk.percent)

            onClicked: Quickshell.execDetached(["thunar", disk.mount])

            Rectangle {
                id: tile

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.topMargin: 12
                width: 34
                height: 34
                radius: 4
                color: Theme.tint(disk.tone, 0.16)

                Lbl {
                    anchors.centerIn: parent
                    text: "\uDB80\uDECA"
                    color: disk.tone
                    font.pixelSize: 18
                }
            }

            Column {
                anchors.left: tile.right
                anchors.leftMargin: 10
                anchors.right: pct.left
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 13
                spacing: 3

                Lbl {
                    width: parent.width
                    text: disk.mount
                    color: Theme.titleColor
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Lbl {
                    width: parent.width
                    text: disk.source + "  " + disk.fs
                    color: Theme.mutedColor
                    font.pixelSize: 9
                }
            }

            Lbl {
                id: pct

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.top: parent.top
                anchors.topMargin: 14
                text: disk.percent + "%"
                color: disk.tone
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Track {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 8
                value: disk.percent
                interactive: false
                tone: disk.tone
            }
        }
    }

    Process {
        id: diskProc

        command: ["sh", Theme.dir + "/storage.sh"]

        stdout: StdioCollector {
            onStreamFinished: page.parse(this.text)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!diskProc.running)
                diskProc.running = true
        }
    }
}
