import QtQuick
import ".."

Item {
    id: root

    height: 42

    property int currentMode: 0
    property bool armed: false
    property real pillP: 1
    readonly property real chipW: Math.max(92, (root.width - 6) / 3)

    signal modeSelected(int mode)

    onCurrentModeChanged: {
        if (root.armed)
            pillPulse.restart()
    }

    Timer {
        running: true
        interval: 80

        onTriggered: root.armed = true
    }

    NumberAnimation {
        id: pillPulse

        target: root
        property: "pillP"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    Rectangle {
        x: root.currentMode * (root.chipW + 3)
        width: root.chipW
        height: 36
        radius: 7
        scale: 1 + 0.06 * Math.sin(root.pillP * Math.PI)
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

        Behavior on x {
            enabled: root.armed

            NumberAnimation {
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        Behavior on width {
            enabled: root.armed

            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Row {
    spacing: 3
    height: 42

    Repeater {
        model: [
            { label: "󰀻  Apps", mode: 0 },
            { label: "󰆍  Run", mode: 1 },
            { label: "󰖯  Windows", mode: 2 }
        ]

        delegate: Rectangle {
            required property var modelData

            property bool hovered: false

            width: root.chipW

            height: 36
            radius: 7

            color:
                root.currentMode === modelData.mode
                ? "transparent"
                : hovered
                    ? Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0.08
                    )
                    : "transparent"

            border.width: 0

            border.color:
                Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.35
                )

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }

            Text {
                anchors.centerIn: parent

                text:
                    modelData.label

                color:
                    root.currentMode === modelData.mode
                    ? Theme.accent
                    : hovered
                        ? Theme.foreground
                        : Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 10

                font.weight:
                    root.currentMode === modelData.mode
                    ? Font.Bold
                    : Font.Normal
            }

            MouseArea {
                anchors.fill: parent

                hoverEnabled: true

                cursorShape:
                    Qt.PointingHandCursor

                onEntered: {
                    parent.hovered = true
                }

                onExited: {
                    parent.hovered = false
                }

                onClicked: {
                    root.modeSelected(
                        modelData.mode
                    )
                }
            }
        }
    }
    }
}
