import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    readonly property string cfg: Theme.configHome

    property string signature: "init"
    property var known: ({})
    property bool primed: false

    ListModel {
        id: configModel
    }

    function sync(text) {
        var out = text.trim()

        if (out === page.signature)
            return

        page.signature = out

        var lines = out === "" ? [] : out.split("\n")
        var rows = []
        var seen = {}

        for (var i = 0; i < lines.length; i++) {
            var p = lines[i].split("\t")

            if (p.length < 4)
                continue

            var isNew = page.primed && !page.known[p[1]]

            seen[p[1]] = true

            rows.push({
                title: p[0],
                path: p[1],
                dir: p[2],
                kind: p[3],
                fresh: isNew || page.freshPaths[p[1]] === true
            })

            if (isNew)
                page.freshPaths[p[1]] = true
        }

        page.known = seen
        page.primed = true

        configModel.clear()

        for (var k = 0; k < rows.length; k++)
            configModel.append(rows[k])
    }

    property var freshPaths: ({})

    function scan() {
        if (!scanProc.running)
            scanProc.running = true
    }

    function openEditor(path) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "if [ -d \"$1\" ]; then exec thunar \"$1\"; fi; for e in code code-oss codium; do command -v \"$e\" >/dev/null 2>&1 && exec \"$e\" \"$1\"; done; exec xdg-open \"$1\"",
            "doiz",
            path
        ])

        Qt.quit()
    }

    function openFolder(path) {
        Quickshell.execDetached(["thunar", path])
        Qt.quit()
    }

    Head {
        id: head

        width: parent.width
        title: "CONFIGURATION FILES"
        info: configModel.count
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom

        contentWidth: width
        contentHeight: grid.height
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

        Grid {
            id: grid

            width: parent.width
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: configModel

                delegate: Card {
                    id: entry

                    required property string title
                    required property string path
                    required property string dir
                    required property string kind
                    required property bool fresh

                    width: (grid.width - 8) / 2
                    height: 52
                    clickable: true
                    selected: entry.fresh
                    tone: entry.fresh ? Theme.goodColor : Theme.accentColor

                    onClicked: page.openEditor(entry.path)

                    Rectangle {
                        id: tile

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        radius: 4
                        color: Theme.tint(entry.fresh ? Theme.goodColor : Theme.accentColor, 0.18)

                        Lbl {
                            anchors.centerIn: parent
                            text: entry.kind === "dir" ? "\uDB80\uDE4B" : "\uDB80\uDE14"
                            color: entry.fresh ? Theme.goodColor : Theme.accentColor
                            font.pixelSize: 16
                        }
                    }

                    Column {
                        anchors.left: tile.right
                        anchors.leftMargin: 10
                        anchors.right: folderBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Row {
                            width: parent.width
                            spacing: 6

                            Lbl {
                                width: Math.min(implicitWidth, parent.width - (newTag.visible ? newTag.width + 6 : 0))
                                text: entry.title
                                color: Theme.titleColor
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                id: newTag

                                visible: entry.fresh
                                width: 28
                                height: 12
                                radius: 3
                                color: Theme.tint(Theme.goodColor, 0.22)

                                Lbl {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "NEW"
                                    color: Theme.goodColor
                                    font.pixelSize: 7
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Lbl {
                            width: parent.width
                            text: entry.path.replace(Theme.home, "~")
                            color: Theme.mutedColor
                            font.pixelSize: 8
                            elide: Text.ElideMiddle
                        }
                    }

                    Btn {
                        id: folderBtn

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32
                        icon: "\uDB81\uDF70"
                        tone: Theme.textColor

                        onClicked: page.openFolder(entry.dir)
                    }
                }
            }
        }
    }

    Process {
        id: scanProc

        command: ["nice", "-n", "19", "sh", Theme.dir + "/configs.sh"]

        stdout: StdioCollector {
            onStreamFinished: page.sync(this.text)
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: page.scan()
    }
}
