import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property string filter: ""
    property bool showAll: false

    ListModel {
        id: keyModel
    }

    Live {
        id: live
    }

    Process {
        id: keyProc

        command: ["python3", Theme.setScript, "keys"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")

                keyModel.clear()

                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")

                    if (p.length >= 2)
                        keyModel.append({ combo: p[0], what: p[1] })
                }
            }
        }
    }

    function matches(combo, what) {
        var f = page.filter.trim().toLowerCase()

        return f === "" || combo.toLowerCase().indexOf(f) >= 0 || what.toLowerCase().indexOf(f) >= 0
    }

    function editor(path) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "for e in code code-oss codium; do command -v \"$e\" >/dev/null 2>&1 && exec \"$e\" \"$1\"; done; exec xdg-open \"$1\"",
            "doiz",
            path
        ])
    }

    Component.onDestruction: Theme.typing = false

    Head {
        id: head

        width: parent.width
        title: "NOTIFICATIONS"
        info: live.on("dnd") ? "DO NOT DISTURB" : "ON"
    }

    Sw {
        id: dnd

        anchors.top: head.bottom
        anchors.topMargin: 6
        width: parent.width
        icon: "󰂛"
        title: "Do not disturb"
        sub: "Synced with the Control Center toggle"
        checked: live.on("dnd")
        activeTone: Theme.warnColor

        onToggled: live.act(["dnd", live.on("dnd") ? "off" : "on"])
    }

    Row {
        id: actions

        anchors.top: dnd.bottom
        anchors.topMargin: 6
        width: parent.width
        spacing: 6

        Btn {
            width: (parent.width - 12) / 3
            icon: "󰂚"
            label: "OPEN CENTER"

            onClicked: {
                Quickshell.execDetached([Theme.configHome + "/hypr/scripts/doiz-controlcenter", "ipc", "call", "controlcenter", "toggle"])
                Qt.quit()
            }
        }

        Btn {
            width: (parent.width - 12) / 3
            icon: "󰌌"
            label: "HELP POPUP"

            onClicked: {
                Quickshell.execDetached(["sh", "-c", "qs -c keybinds ipc call keybinds toggle || qs -c keybinds -n"])
                Qt.quit()
            }
        }

        Btn {
            width: (parent.width - 12) / 3
            icon: "󰈔"
            label: "CUSTOM KEYS"

            onClicked: page.editor(Theme.configHome + "/mycfg/custom-keys.lua")
        }
    }

    Head {
        id: keyHead

        anchors.top: actions.bottom
        anchors.topMargin: 10
        width: parent.width
        title: "KEYBINDS"
        info: keyModel.count
    }

    Rectangle {
        id: search

        anchors.top: keyHead.bottom
        anchors.topMargin: 4
        width: parent.width
        height: 30
        radius: 8
        color: Theme.cardColor
        border.width: 1
        border.color: field.activeFocus ? Theme.stateColor : Theme.lineColor

        TextField {
            id: field

            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            placeholderText: "Search key or action"
            placeholderTextColor: Theme.mutedColor
            color: Theme.titleColor
            font.family: Theme.fontName
            font.pixelSize: 10
            verticalAlignment: TextInput.AlignVCenter
            background: null

            onActiveFocusChanged: Theme.typing = activeFocus
            onTextChanged: page.filter = text
        }
    }

    ListView {
        anchors.top: search.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        model: keyModel
        spacing: 0
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

        delegate: Item {
            id: row

            required property string combo
            required property string what

            width: ListView.view.width
            height: page.matches(row.combo, row.what) ? 31 : 0
            visible: height > 0

            Card {
                width: parent.width
                height: 28

                Lbl {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.combo.replace(/\+/g, "  +  ")
                    color: Theme.stateColor
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }

                Lbl {
                    anchors.left: parent.horizontalCenter
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.what
                    color: Theme.textColor
                    font.pixelSize: 10
                }
            }
        }
    }
}
