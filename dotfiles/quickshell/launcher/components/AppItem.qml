import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: root

    property var app
    property bool selected: false
    property bool hovered: false

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

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: appIcon

                anchors.fill: parent

                visible:
                    root.app &&
                    root.app.icon &&
                    String(root.app.icon).length > 0 &&
                    Quickshell.hasThemeIcon(
                        String(root.app.icon)
                    )

                source:
                    visible
                    ? Quickshell.iconPath(
                        String(root.app.icon),
                        true
                    )
                    : ""

                implicitSize: 32
                asynchronous: true
            }

            Text {
                anchors.fill: parent

                visible:
                    !appIcon.visible

                text: "󰀻"

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
                    root.app &&
                    root.app.name
                    ? String(root.app.name)
                    : "Application"

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
                    root.app &&
                    root.app.genericName
                    ? String(root.app.genericName)
                    : root.app &&
                      root.app.id
                        ? String(root.app.id)
                        : "Application"

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