import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "."

Item {
    id: page

    property string newCmd: ""

    readonly property var groups: [
        { key: "terminal", title: "Terminal", apps: ["kitty", "alacritty", "foot", "wezterm", "konsole"] },
        { key: "browser", title: "Browser", apps: ["helium-browser", "firefox", "chromium", "brave", "google-chrome-stable", "zen-browser"] },
        { key: "file_manager", title: "File manager", apps: ["thunar", "nautilus", "dolphin", "pcmanfm", "nemo"] }
    ]

    property var autostart: []
    property var excludePatterns: []
    property var openClasses: []
    property var appItems: []

    function escapeRegex(str) {
        return String(str).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function exactPattern(cls) {
        return "^" + escapeRegex(cls) + "$"
    }

    function patternClass(pat) {
        var m = /^\^(.*)\$$/.exec(pat)

        if (!m || /(^|[^\\])[*+?|()\[\]{}^$]/.test(m[1].replace(/\\./g, "")))
            return ""

        return m[1].replace(/\\(.)/g, "$1")
    }

    property string appFilter: ""
    property string appItemsKey: ""
    property int keptTotal: 0

    readonly property var skipExec: ["env", "sh", "bash", "zsh", "fish", "flatpak", "snap", "gtk-launch",
                                     "xdg-open", "gio", "sudo", "pkexec", "kdesu", "uwsm", "uwsm-app",
                                     "python", "python3", "java", "wine", "steam-runtime"]

    function patternFor(cands) {
        if (cands.length === 1)
            return exactPattern(cands[0])

        return "^(" + cands.map(escapeRegex).join("|") + ")$"
    }

    function matchesAny(rx, cands) {
        for (var i = 0; i < cands.length; i++)
            if (rx.test(cands[i]))
                return true

        return false
    }

    function candidatesOf(entry) {
        var out = []
        var seen = {}

        function add(v) {
            v = String(v || "").trim()

            if (v === "" || seen[v.toLowerCase()])
                return

            seen[v.toLowerCase()] = true
            out.push(v)
        }

        add(entry.startupClass)
        add(String(entry.id || "").replace(/\.desktop$/i, ""))

        if (entry.command && entry.command.length > 0) {
            var exe = String(entry.command[0]).split("/").pop()

            if (page.skipExec.indexOf(exe) < 0)
                add(exe)
        }

        return out
    }

    function rebuildApps() {
        var apps = DesktopEntries.applications.values
        var openSet = {}
        var i, j

        for (i = 0; i < openClasses.length; i++)
            openSet[openClasses[i].toLowerCase()] = true

        var rxs = []

        for (i = 0; i < excludePatterns.length; i++) {
            try {
                rxs.push({ src: excludePatterns[i], rx: new RegExp(excludePatterns[i], "i") })
            } catch (e) {}
        }

        function isKept(pat, cands) {
            for (var k = 0; k < rxs.length; k++)
                if (rxs[k].src === pat || matchesAny(rxs[k].rx, cands))
                    return true

            return false
        }

        var items = []
        var covered = {}

        for (i = 0; i < apps.length; i++) {
            var e = apps[i]

            if (e.noDisplay)
                continue

            var cands = candidatesOf(e)

            if (cands.length === 0)
                continue

            var pat = patternFor(cands)
            var icon = String(e.icon || "")
            var isOpen = false

            for (j = 0; j < cands.length; j++) {
                covered[cands[j].toLowerCase()] = true

                if (openSet[cands[j].toLowerCase()])
                    isOpen = true
            }

            if (icon.charAt(0) === "/")
                icon = "file://" + icon
            else if (icon !== "")
                icon = Quickshell.iconPath(icon, true)

            items.push({ name: String(e.name || cands[0]), pat: pat, cands: cands, icon: icon,
                         open: isOpen, kept: isKept(pat, cands) })
        }

        for (i = 0; i < openClasses.length; i++) {
            var oc = openClasses[i]

            if (covered[oc.toLowerCase()])
                continue

            covered[oc.toLowerCase()] = true
            items.push({ name: oc, pat: exactPattern(oc), cands: [oc], icon: "", open: true,
                         kept: isKept(exactPattern(oc), [oc]) })
        }

        for (i = 0; i < excludePatterns.length; i++) {
            var pc = patternClass(excludePatterns[i])

            if (pc === "" || covered[pc.toLowerCase()])
                continue

            covered[pc.toLowerCase()] = true
            items.push({ name: pc, pat: excludePatterns[i], cands: [pc], icon: "", open: false, kept: true })
        }

        var total = 0

        for (i = 0; i < items.length; i++)
            if (items[i].kept)
                total++

        keptTotal = total

        var q = appFilter.trim().toLowerCase()

        if (q !== "") {
            items = items.filter(function(it) {
                return it.name.toLowerCase().indexOf(q) >= 0 || it.cands.join(" ").toLowerCase().indexOf(q) >= 0
            })
        }

        items.sort(function(x, y) {
            if (x.kept !== y.kept)
                return x.kept ? -1 : 1

            if (x.open !== y.open)
                return x.open ? -1 : 1

            return x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1
        })

        var key = JSON.stringify(items)

        if (key === appItemsKey)
            return

        appItemsKey = key
        appItems = items
    }

    function toggleKeep(item, keep) {
        var list = excludePatterns.filter(function(x) { return x !== item.pat })

        if (keep)
            list.push(item.pat)

        excludePatterns = list
        rebuildApps()

        Quickshell.execDetached(["bash", "-c",
            "f=\"$HOME/.config/mycfg/blackhole-exclude.txt\"; mkdir -p \"$(dirname \"$f\")\"; touch \"$f\"; " +
            "{ grep -vxF -- \"$2\" \"$f\" || true; } > \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; " +
            "if [ \"$1\" = 1 ]; then printf '%s\\n' \"$2\" >> \"$f\"; fi",
            "_", keep ? "1" : "0", item.pat])
    }

    onAppFilterChanged: rebuildApps()

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            page.rebuildApps()
        }
    }

    Component.onCompleted: rebuildApps()

    Process {
        id: excludeProc

        command: ["bash", "-c", "cat \"$HOME/.config/mycfg/blackhole-exclude.txt\" 2>/dev/null || true"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                var out = []

                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()

                    if (l.length > 0 && l.charAt(0) !== "#")
                        out.push(l)
                }

                page.excludePatterns = out
                page.rebuildApps()
            }
        }
    }

    Process {
        id: clientsProc

        command: ["hyprctl", "clients", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var out = []

                try {
                    var data = JSON.parse(this.text || "[]")

                    for (var i = 0; i < data.length; i++) {
                        var cls = String(data[i]["class"] || "").trim()

                        if (cls.length > 0 && data[i].mapped !== false)
                            out.push(cls)
                    }
                } catch (e) {}

                page.openClasses = out
                page.rebuildApps()
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true

        onTriggered: {
            if (!clientsProc.running)
                clientsProc.running = true
        }
    }

    Live {
        id: live
    }

    Process {
        id: autoProc

        command: ["python3", Theme.setScript, "autostart", "list"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()

                page.autostart = t === "" ? [] : t.split("\n")
            }
        }
    }

    function auto(args) {
        Theme.run(["autostart"].concat(args))
        reload.restart()
    }

    Timer {
        id: reload

        interval: 500

        onTriggered: autoProc.running = true
    }

    Component.onDestruction: Theme.typing = false

    Head {
        id: head

        width: parent.width
        title: "HYPRLAND"
        info: live.on("infinite") ? "INFINITE DESKTOP ON" : "INFINITE DESKTOP OFF"
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: col.height + 8
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

        Column {
            id: col

            width: parent.width - 6
            spacing: 6

            Sw {
                width: parent.width
                icon: "\uDB80\uDC3B"
                title: "Infinite Desktop"
                sub: "Super+Shift+D"
                checked: live.on("infinite")

                onToggled: {
                    Quickshell.execDetached([Theme.configHome + "/hypr/scripts/toggle-infinite-desktop"])
                    live.act(["get"])
                }
            }

            Sw {
                width: parent.width
                icon: "\uDB80\uDF79"
                title: "Auto arrange grid"
                sub: "Super+Shift+A"
                checked: live.on("grid")

                onToggled: {
                    Quickshell.execDetached([Theme.configHome + "/hypr/scripts/toggle-auto-arrange-grid"])
                    live.act(["get"])
                }
            }

            Sw {
                width: parent.width
                icon: "\uDB81\uDF0A"
                title: "Animations"
                checked: live.on("animations")

                onToggled: live.act(["set", "animations", live.on("animations") ? "0" : "1"])
            }

            Sld {
                width: parent.width
                title: "Inner gaps"
                unit: " px"
                to: 40
                value: Number(live.get("gaps_in", 5))

                onCommitted: (v) => live.act(["set", "gaps_in", String(v)])
            }

            Sld {
                width: parent.width
                title: "Outer gaps"
                unit: " px"
                to: 60
                value: Number(live.get("gaps_out", 10))

                onCommitted: (v) => live.act(["set", "gaps_out", String(v)])
            }

            Row {
                width: parent.width
                spacing: 6

                Btn {
                    width: (parent.width - 12) / 3
                    label: "EFFECTS"

                    onClicked: {
                        Quickshell.execDetached(["sh", "-c", "qs -c effects ipc call effects toggle || qs -c effects -n"])
                        Qt.quit()
                    }
                }

                Btn {
                    width: (parent.width - 12) / 3
                    label: "RELOAD HYPRLAND"

                    onClicked: Quickshell.execDetached(["hyprctl", "reload"])
                }

                Btn {
                    width: (parent.width - 12) / 3
                    label: "BLACK HOLE TEST"

                    onClicked: {
                        Quickshell.execDetached([Theme.configHome + "/hypr/scripts/blackhole", "--dry"])
                        Qt.quit()
                    }
                }
            }

            Repeater {
                model: page.groups

                delegate: Column {
                    id: grp

                    required property var modelData

                    width: col.width
                    spacing: 4

                    Head {
                        width: parent.width
                        title: "DEFAULT " + grp.modelData.title.toUpperCase()
                        info: live.get(grp.modelData.key, "")
                    }

                    Flow {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: grp.modelData.apps

                            delegate: Btn {
                                required property string modelData

                                readonly property bool current: live.get(grp.modelData.key, "") === modelData
                                readonly property bool installed: live.get("has_" + modelData, "0") === "1"

                                label: modelData.toUpperCase()
                                filled: current
                                tone: current ? Theme.goodColor : Theme.textColor
                                enabled: installed || current

                                onClicked: live.act(["set", grp.modelData.key, modelData])
                            }
                        }
                    }
                }
            }

            Head {
                width: parent.width
                title: "AUTOSTART"
                info: page.autostart.length
            }

            Repeater {
                model: page.autostart

                delegate: Card {
                    required property string modelData
                    required property int index

                    width: col.width
                    height: 30

                    Lbl {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: rm.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: Theme.titleColor
                        font.pixelSize: 10
                    }

                    Btn {
                        id: rm

                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 24
                        icon: "\uDB80\uDD56"
                        iconSize: 12
                        tone: Theme.badColor

                        onClicked: page.auto(["del", String(index)])
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width - addBtn.width - 6
                    height: 34
                    radius: 8
                    color: Theme.cardColor
                    border.width: 1
                    border.color: cmd.activeFocus ? Theme.stateColor : Theme.lineColor

                    TextField {
                        id: cmd

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        placeholderText: "Command to run at login, e.g. discord"
                        placeholderTextColor: Theme.mutedColor
                        color: Theme.titleColor
                        font.family: Theme.fontName
                        font.pixelSize: 10
                        verticalAlignment: TextInput.AlignVCenter
                        background: null

                        onActiveFocusChanged: Theme.typing = activeFocus
                        onAccepted: addBtn.clicked()
                    }
                }

                Btn {
                    id: addBtn

                    height: 34
                    label: "ADD"
                    filled: true
                    tone: Theme.goodColor

                    onClicked: {
                        if (cmd.text.trim() === "")
                            return

                        page.auto(["add", cmd.text.trim()])
                        cmd.text = ""
                    }
                }
            }

            Head {
                width: parent.width
                title: "BLACK HOLE: KEEP OPEN"
                info: page.keptTotal + " kept"
            }

            Lbl {
                width: parent.width
                text: "Ticked apps are not closed by Super+Shift+B"
                color: Theme.mutedColor
                font.pixelSize: 8
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: 8
                color: Theme.cardColor
                border.width: 1
                border.color: filterField.activeFocus ? Theme.stateColor : Theme.lineColor

                TextField {
                    id: filterField

                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    placeholderText: "Search apps"
                    placeholderTextColor: Theme.mutedColor
                    color: Theme.titleColor
                    font.family: Theme.fontName
                    font.pixelSize: 10
                    verticalAlignment: TextInput.AlignVCenter
                    background: null

                    onActiveFocusChanged: Theme.typing = activeFocus
                    onTextChanged: page.appFilter = text
                    onAccepted: focus = false
                    Component.onDestruction: Theme.typing = false

                    Keys.onEscapePressed: (event) => {
                        if (activeFocus) {
                            focus = false
                            event.accepted = true
                        } else {
                            event.accepted = false
                        }
                    }
                }
            }

            Repeater {
                model: page.appItems

                delegate: Card {
                    id: appRow

                    required property var modelData

                    width: col.width
                    height: 34
                    clickable: true
                    selected: modelData.kept
                    tone: Theme.goodColor

                    onClicked: page.toggleKeep(modelData, !modelData.kept)

                    Item {
                        id: appIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20

                        Image {
                            anchors.fill: parent
                            source: appRow.modelData.icon
                            sourceSize.width: 40
                            sourceSize.height: 40
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Lbl {
                            anchors.centerIn: parent
                            visible: appRow.modelData.icon === ""
                            text: appRow.modelData.name.charAt(0).toUpperCase()
                            color: Theme.mutedColor
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    Lbl {
                        anchors.left: appIcon.right
                        anchors.leftMargin: 10
                        anchors.right: tag.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: appRow.modelData.name
                        color: appRow.modelData.kept ? Theme.titleColor : Theme.textColor
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Row {
                        id: tag

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Lbl {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: appRow.modelData.open
                            text: "open"
                            color: Theme.stateColor
                            font.pixelSize: 8
                        }

                        Lbl {
                            anchors.verticalCenter: parent.verticalCenter
                            text: appRow.modelData.kept ? "\uDB80\uDD33" : "\uDB80\uDD30"
                            color: appRow.modelData.kept ? Theme.goodColor : Theme.mutedColor
                            font.pixelSize: 15
                        }
                    }
                }
            }

            Lbl {
                width: parent.width
                visible: page.appItems.length === 0
                text: "No apps found"
                color: Theme.mutedColor
                font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
