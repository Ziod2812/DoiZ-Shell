import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property string filter: ""
    property bool aurOnly: false
    property bool guiOnly: false
    property string selected: ""
    property string term: "kitty"

    ListModel {
        id: pkgModel
    }

    Live {
        id: live

        onVersionChanged: page.term = live.get("terminal", "kitty")
    }

    function load() {
        if (!proc.running)
            proc.running = true
    }

    function inTerminal(script, arg) {
        var t = page.term
        var pre = t === "wezterm" ? ["wezterm", "start", "--"] : [t, "-e"]

        Quickshell.execDetached(pre.concat(["sh", "-c", script, "doiz", arg]))
        reload.restart()
    }

    function aurHelper() {
        return "if command -v yay >/dev/null 2>&1; then H=yay; elif command -v paru >/dev/null 2>&1; then H=paru; else H='sudo pacman'; fi; "
    }

    function removeSelected() {
        if (!/^[A-Za-z0-9@._+-]+$/.test(page.selected))
            return

        inTerminal(aurHelper() + "$H -Rns \"$1\"; echo; printf 'Press Enter to close'; read _", page.selected)
        page.selected = ""
    }

    function install(name) {
        if (!/^[A-Za-z0-9@._+-]+$/.test(name))
            return

        inTerminal(aurHelper() + "$H -S \"$1\"; echo; printf 'Press Enter to close'; read _", name)
    }

    function updateAll() {
        inTerminal(aurHelper() + "$H -Syu; echo; printf 'Press Enter to close'; read _", "")
    }

    Timer {
        id: reload

        interval: 8000

        onTriggered: page.load()
    }

    Process {
        id: proc

        command: ["python3", Theme.setScript, "pkgs"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")

                pkgModel.clear()

                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")

                    if (p.length >= 3)
                        pkgModel.append({ name: p[0], ver: p[1], src: p[2], icon: p.length > 3 ? p[3] : "" })
                }
            }
        }
    }

    Component.onDestruction: Theme.typing = false

    Head {
        id: head

        width: parent.width
        title: "INSTALLED PACKAGES"
        info: pkgModel.count
    }

    Row {
        id: bar

        anchors.top: head.bottom
        anchors.topMargin: 6
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width - allBtn.width - guiBtn.width - aurBtn.width - 18
            height: 32
            radius: 8
            color: Theme.cardColor
            border.width: 1
            border.color: search.activeFocus ? Theme.stateColor : Theme.lineColor

            TextField {
                id: search

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                placeholderText: "Search installed apps"
                placeholderTextColor: Theme.mutedColor
                color: Theme.titleColor
                font.family: Theme.fontName
                font.pixelSize: 10
                verticalAlignment: TextInput.AlignVCenter
                background: null

                onActiveFocusChanged: Theme.typing = activeFocus
                onTextChanged: page.filter = text.toLowerCase()
            }
        }

        Btn {
            id: allBtn

            height: 32
            label: "ALL"
            filled: !page.aurOnly && !page.guiOnly
            tone: Theme.goodColor

            onClicked: {
                page.aurOnly = false
                page.guiOnly = false
            }
        }

        Btn {
            id: guiBtn

            height: 32
            label: "APPS"
            filled: page.guiOnly
            tone: Theme.infoColor

            onClicked: {
                page.guiOnly = true
                page.aurOnly = false
            }
        }

        Btn {
            id: aurBtn

            height: 32
            label: "AUR"
            filled: page.aurOnly
            tone: Theme.warnColor

            onClicked: {
                page.aurOnly = true
                page.guiOnly = false
            }
        }
    }

    ListView {
        id: list

        anchors.top: bar.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.bottomMargin: 6
        model: pkgModel
        clip: true
        spacing: 0
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

            required property string name
            required property string ver
            required property string src
            required property string icon

            readonly property bool shown:
                (!page.aurOnly || row.src === "aur") && (!page.guiOnly || row.icon !== "")
                && (page.filter === "" || row.name.toLowerCase().indexOf(page.filter) >= 0)

            width: ListView.view.width
            height: row.shown ? 38 : 0
            visible: row.shown

            Card {
                width: parent.width
                height: 35
                clickable: true
                selected: page.selected === row.name
                tone: Theme.badColor

                onClicked: page.selected = row.name

                Rectangle {
                    id: iconTile

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 5
                    color: Theme.tint(Theme.stateColor, 0.14)

                    Image {
                        id: appIcon

                        anchors.fill: parent
                        anchors.margins: 2
                        source: row.icon === "" ? "" : (row.icon.indexOf("/") === 0 ? "file://" + row.icon : Quickshell.iconPath(row.icon, true))
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }

                    Lbl {
                        anchors.centerIn: parent
                        visible: !appIcon.visible
                        text: row.name.charAt(0).toUpperCase()
                        color: Theme.stateColor
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                Lbl {
                    anchors.left: iconTile.right
                    anchors.leftMargin: 10
                    anchors.right: tag.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.name
                    color: Theme.titleColor
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Lbl {
                    id: tag

                    anchors.right: ver.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.src.toUpperCase()
                    color: row.src === "aur" ? Theme.warnColor : Theme.mutedColor
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }

                Lbl {
                    id: ver

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    horizontalAlignment: Text.AlignRight
                    text: row.ver
                    color: Theme.mutedColor
                    font.pixelSize: 9
                }
            }
        }
    }

    Column {
        id: actions

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6

        Row {
            width: parent.width
            spacing: 6

            Btn {
                width: (parent.width - 12) / 3 * 2
                height: 34
                enabled: page.selected !== ""
                label: page.selected === "" ? "SELECT AN APP TO REMOVE" : "REMOVE  " + page.selected.toUpperCase()
                filled: page.selected !== ""
                tone: Theme.badColor

                onClicked: page.removeSelected()
            }

            Btn {
                width: (parent.width - 12) / 6
                height: 34
                label: "UPDATE"
                tone: Theme.infoColor

                onClicked: page.updateAll()
            }

            Btn {
                width: (parent.width - 12) / 6
                height: 34
                label: "REFRESH"

                onClicked: page.load()
            }
        }

        Row {
            width: parent.width
            spacing: 6

            Rectangle {
                width: parent.width - installBtn.width - 6
                height: 34
                radius: 8
                color: Theme.cardColor
                border.width: 1
                border.color: pkgName.activeFocus ? Theme.stateColor : Theme.lineColor

                TextField {
                    id: pkgName

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    placeholderText: "Package to install (repo or AUR)"
                    placeholderTextColor: Theme.mutedColor
                    color: Theme.titleColor
                    font.family: Theme.fontName
                    font.pixelSize: 10
                    verticalAlignment: TextInput.AlignVCenter
                    background: null

                    onActiveFocusChanged: Theme.typing = activeFocus
                    onAccepted: installBtn.clicked()
                }
            }

            Btn {
                id: installBtn

                height: 34
                label: "INSTALL"
                filled: true
                tone: Theme.goodColor

                onClicked: {
                    page.install(pkgName.text.trim())
                    pkgName.text = ""
                }
            }
        }
    }
}
