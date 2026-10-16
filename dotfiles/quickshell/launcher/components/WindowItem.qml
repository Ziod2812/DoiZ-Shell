import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: root

    property var windowItem
    property bool selected: false
    property bool hovered: false
    property var desktopEntry: null
    property string iconName: ""

    signal triggered()

    height: 52
    radius: 9

    color:
        root.selected
        ? Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.14
        )
        : root.hovered
            ? Qt.rgba(
                Theme.accent.r,
                Theme.accent.g,
                Theme.accent.b,
                0.08
            )
            : "transparent"

    border.width:
        root.selected
        ? 1
        : 0

    border.color:
        Qt.rgba(
            Theme.accent.r,
            Theme.accent.g,
            Theme.accent.b,
            0.34
        )

    Behavior on color {
        ColorAnimation {
            duration: 100
        }
    }

    function resolveIcon() {
        root.desktopEntry = null
        root.iconName = ""

        if (
            !root.windowItem ||
            !root.windowItem.appId
        ) {
            return
        }

        var appId =
            String(
                root.windowItem.appId
            )

        var entry =
            DesktopEntries.heuristicLookup(
                appId
            )

        if (entry) {
            root.desktopEntry = entry

            if (
                entry.icon &&
                String(entry.icon).length > 0
            ) {
                root.iconName =
                    String(entry.icon)

                return
            }
        }

        if (
            Quickshell.hasThemeIcon(
                appId
            )
        ) {
            root.iconName = appId
            return
        }

        if (appId.toLowerCase().indexOf("helium") !== -1) {
            var hn = ["helium", "helium-browser", "net.imput.helium"]

            for (var hi = 0; hi < hn.length; hi++) {
                if (Quickshell.hasThemeIcon(hn[hi])) {
                    root.iconName = hn[hi]
                    return
                }
            }
        }
    }

    onWindowItemChanged: {
        root.resolveIcon()
    }

    Component.onCompleted: {
        root.resolveIcon()
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Item {
            width: 32
            height: 32

            anchors.verticalCenter:
                parent.verticalCenter

            IconImage {
                id: windowIcon

                anchors.fill: parent

                visible:
                    root.iconName.length > 0 &&
                    Quickshell.hasThemeIcon(
                        root.iconName
                    )

                source:
                    visible
                    ? Quickshell.iconPath(
                        root.iconName,
                        true
                    )
                    : ""

                implicitSize: 32
                asynchronous: true
            }

            Text {
                anchors.fill: parent

                visible:
                    !windowIcon.visible

                text: "󰖯"

                color:
                    root.selected
                    ? Theme.accent
                    : Theme.subtext

                font.family:
                    Theme.fontFamily

                font.pixelSize: 20

                horizontalAlignment:
                    Text.AlignHCenter

                verticalAlignment:
                    Text.AlignVCenter
            }
        }

        Column {
            anchors.verticalCenter:
                parent.verticalCenter

            width:
                parent.width - 44

            spacing: 2

            Text {
                width:
                    parent.width

                text:
                    root.windowItem &&
                    root.windowItem.title
                    ? String(
                        root.windowItem.title
                    )
                    : "Window"

                color:
                    root.selected
                    ? Theme.foreground
                    : Theme.subtext

                font.family:
                    Theme.fontFamily

                font.pixelSize: 11

                font.weight:
                    Font.DemiBold

                elide:
                    Text.ElideRight

                verticalAlignment:
                    Text.AlignVCenter
            }

            Text {
                width:
                    parent.width

                text:
                    root.windowItem &&
                    root.windowItem.appId
                    ? String(
                        root.windowItem.appId
                    )
                    : "Wayland Window"

                color:
                    Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 9

                elide:
                    Text.ElideRight

                verticalAlignment:
                    Text.AlignVCenter
            }
        }
    }

    Rectangle {
        visible:
            root.selected

        width: 3
        height: 22

        radius: 2

        anchors.left:
            parent.left

        anchors.leftMargin:
            2

        anchors.verticalCenter:
            parent.verticalCenter

        color:
            Theme.accent
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape:
            Qt.PointingHandCursor

        onEntered: {
            root.hovered = true
        }

        onExited: {
            root.hovered = false
        }

        onClicked: {
            root.triggered()
        }
    }
}