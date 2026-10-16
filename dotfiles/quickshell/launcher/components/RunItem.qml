import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: root

    property string command: ""
    property bool selected: false
    property bool hovered: false
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
        root.iconName = ""

        var name =
            String(root.command || "").trim()

        if (!name)
            return

        if (
            Quickshell.hasThemeIcon(name)
        ) {
            root.iconName = name
            return
        }

        var entry =
            DesktopEntries.heuristicLookup(
                name
            )

        if (
            entry &&
            entry.icon &&
            String(entry.icon).length > 0
        ) {
            var icon =
                String(entry.icon)

            if (
                Quickshell.hasThemeIcon(icon)
            ) {
                root.iconName = icon
            }
        }
    }

    onCommandChanged: {
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
                id: commandIcon

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
                    !commandIcon.visible

                text: "󰆍"

                color:
                    root.selected
                    ? Theme.accent
                    : Theme.subtext

                font.family:
                    Theme.fontFamily

                font.pixelSize: 19

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
                    root.command.length > 0
                    ? root.command
                    : "Command"

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
                    root.iconName.length > 0
                    ? "Executable · Application"
                    : "Executable"

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