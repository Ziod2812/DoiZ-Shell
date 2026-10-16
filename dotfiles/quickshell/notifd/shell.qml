import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property var items: []
    property var refs: ({})
    property int limit: 30

    property bool dnd: false
    property var popups: []

    property color bgColor: "#12141f"
    property color cardColor: "#1f2231"
    property color accentColor: "#cba6f7"
    property color titleColor: "#ebeffa"
    property color textColor: "#cdd3e6"
    property color dangerColor: "#f38ba8"
    property string fontName: "JetBrainsMono Nerd Font"

    readonly property string cfgDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")

    FileView {
        id: dndFile
        path: root.cfgDir + "/mycfg/dnd"
        blockLoading: true
        onLoaded: root.dnd = text().trim() === "1"
        onLoadFailed: root.dnd = false
    }

    FileView {
        id: themeFile
        path: root.cfgDir + "/theme/theme.conf"
        blockLoading: true
        onLoaded: root.applyTheme(text())
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            dndFile.reload()
            themeFile.reload()
        }
    }

    function applyTheme(data) {
        var inColors = false
        var c = {}
        var lines = data.split(/\r?\n/)

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line || line.indexOf("#") === 0)
                continue

            if (line.indexOf("[") === 0) {
                inColors = line === "[colors]"
                continue
            }

            var eq = line.indexOf("=")

            if (!inColors || eq === -1)
                continue

            var v = line.substring(eq + 1).trim().split(" ")[0]

            if (/^#[0-9a-fA-F]{6,8}$/.test(v))
                c[line.substring(0, eq).trim()] = v
        }

        if (c["background"]) root.bgColor = c["background"]
        if (c["surface"]) root.cardColor = c["surface"]
        if (c["accent"]) root.accentColor = c["accent"]
        if (c["foreground"]) root.titleColor = c["foreground"]
        if (c["subtext"]) root.textColor = c["subtext"]
        if (c["red"]) root.dangerColor = c["red"]
    }

    function inList(id) {
        var key = String(id)

        for (var i = 0; i < root.items.length; i++) {
            if (String(root.items[i].id) === key)
                return true
        }

        return false
    }

    function closePopup(id) {
        var key = String(id)

        root.popups = root.popups.filter(function(p) {
            return String(p.id) !== key
        })

        if (!root.inList(key))
            root.drop(key)
    }

    function activate(id) {
        var n = root.refs[String(id)]

        if (!n)
            return

        var pick = null

        for (var i = 0; i < n.actions.length; i++) {
            if (n.actions[i].identifier === "default") {
                pick = n.actions[i]
                break
            }

            if (!pick)
                pick = n.actions[i]
        }

        if (pick)
            pick.invoke()
        else if (n.desktopEntry && n.desktopEntry.length > 0)
            Quickshell.execDetached(["gtk-launch", n.desktopEntry])
    }

    function snapshot() {
        return JSON.stringify(root.items)
    }

    function drop(id) {
        var key = String(id)
        var n = root.refs[key]

        if (n) {
            try {
                n.dismiss()
            } catch (e) {
            }
        }

        delete root.refs[key]
        root.items = root.items.filter(function(it) {
            return String(it.id) !== key
        })
    }

    IpcHandler {
        target: "notifd"

        function list(): string {
            return root.snapshot()
        }

        function dismiss(id: string): void {
            root.drop(id)
        }

        function clear(): void {
            var ids = root.items.map(function(it) {
                return it.id
            })

            for (var i = 0; i < ids.length; i++)
                root.drop(ids[i])
        }

        function invoke(id: string): void {
            root.activate(id)
        }
    }

    NotificationServer {
        imageSupported: true
        bodySupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(n) {
            n.tracked = true
            root.refs[String(n.id)] = n

            dndFile.reload()

            var entry = {
                id: n.id,
                app: n.appName || "Notification",
                icon: n.appIcon || n.image || "",
                title: n.summary || "Notification",
                body: n.body || "",
                time: Qt.formatTime(new Date(), "hh:mm")
            }

            n.closed.connect(function() {
                delete root.refs[String(n.id)]

                root.items = root.items.filter(function(it) {
                    return it.id !== n.id
                })

                root.popups = root.popups.filter(function(p) {
                    return p.id !== n.id
                })
            })

            if (!root.dnd) {
                var ms = n.expireTimeout > 0 ? n.expireTimeout * 1000 : 6000

                if (n.urgency === NotificationUrgency.Critical)
                    ms = 0

                entry.ms = ms
                entry.critical = n.urgency === NotificationUrgency.Critical

                var shown = root.popups.filter(function(p) {
                    return p.id !== n.id
                })

                shown.push(entry)

                while (shown.length > 5)
                    shown.shift()

                root.popups = shown
                return
            }

            var next = root.items.filter(function(it) {
                return it.id !== n.id
            })

            next.unshift(entry)

            while (next.length > root.limit) {
                var old = next.pop()
                var o = root.refs[String(old.id)]

                if (o) {
                    try {
                        o.dismiss()
                    } catch (e) {
                    }
                }

                delete root.refs[String(old.id)]
            }

            root.items = next
        }
    }

    PanelWindow {
        id: popupWindow

        visible: root.popups.length > 0
        color: "transparent"

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 8
        }

        implicitWidth: 330
        implicitHeight: Math.max(1, stack.implicitHeight)

        WlrLayershell.namespace: "doiz_notification_popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        ColumnLayout {
            id: stack

            width: parent.width
            spacing: 8

            Repeater {
                model: root.popups

                delegate: Rectangle {
                    id: card

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: Math.max(row.implicitHeight, 40) + 28
                    radius: 12
                    color: Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, 0.94)
                    border.width: 1
                    border.color: modelData.critical
                        ? root.dangerColor
                        : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)

                    Timer {
                        interval: card.modelData.ms
                        running: card.modelData.ms > 0 && !hover.hovered
                        repeat: false
                        onTriggered: root.closePopup(card.modelData.id)
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.activate(card.modelData.id)
                            root.closePopup(card.modelData.id)
                        }
                    }

                    RowLayout {
                        id: row

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 8
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)

                            Image {
                                id: appIcon

                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                sourceSize: Qt.size(48, 48)
                                visible: status === Image.Ready
                                source: {
                                    var ic = card.modelData.icon

                                    if (!ic)
                                        return ""

                                    if (ic.indexOf("/") === 0)
                                        return "file://" + ic

                                    return Quickshell.iconPath(ic, true)
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: "󰂚"
                                color: root.accentColor
                                font.family: root.fontName
                                font.pixelSize: 18
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: card.modelData.app
                                    color: root.accentColor
                                    elide: Text.ElideRight
                                    font.family: root.fontName
                                    font.pixelSize: 9
                                }

                                Text {
                                    text: card.modelData.time
                                    color: root.textColor
                                    font.family: root.fontName
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.title
                                color: root.titleColor
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.family: root.fontName
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: card.modelData.body.length > 0
                                text: card.modelData.body
                                color: root.textColor
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                font.family: root.fontName
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
