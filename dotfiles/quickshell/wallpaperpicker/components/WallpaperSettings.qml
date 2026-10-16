import QtQuick
import QtQuick.Controls
import ".."

Column {
    id: root

    spacing: 6

    property var service: null

    property string currentTransition:
        root.service
        ? String(root.service.transition)
        : "grow"

    property real currentDuration:
        root.service
        ? Number(root.service.duration)
        : 0.6

    function syncService() {
        if (!root.service)
            return

        root.currentTransition =
            String(root.service.transition)

        root.currentDuration =
            Number(root.service.duration)

        folderInput.text =
            root.service.wallpaperDir
    }

    function saveFolder() {
        if (!root.service)
            return

        var path =
            folderInput.text.trim()

        if (!path)
            return

        root.service.setWallpaperDir(path)

        folderInput.text =
            root.service.wallpaperDir

        folderInput.deselect()
        folderInput.focus = false
    }

    function changeTransition() {
        var values = [
            "none",
            "simple",
            "fade",
            "left",
            "right",
            "top",
            "bottom",
            "wipe",
            "wave",
            "grow",
            "center",
            "any",
            "outer",
            "random"
        ]

        var current =
            String(root.currentTransition)

        var index =
            values.indexOf(current)

        if (index < 0)
            index = 0

        var next =
            values[
                (index + 1) % values.length
            ]

        root.currentTransition =
            next

        if (root.service) {
            root.service.setTransition(next)

            root.currentTransition =
                String(
                    root.service.transition
                )
        }
    }

    function changeDuration() {
        var values = [
            0.1,
            0.2,
            0.3,
            0.5,
            0.8,
            1.0,
            1.5,
            2.0,
            3.0,
            5.0
        ]

        var current =
            Number(root.currentDuration)

        var index = -1

        for (
            var i = 0;
            i < values.length;
            i++
        ) {
            if (
                Math.abs(
                    values[i] - current
                ) < 0.001
            ) {
                index = i
                break
            }
        }

        if (index < 0)
            index = 0

        var next =
            values[
                (index + 1) % values.length
            ]

        root.currentDuration =
            next

        if (root.service) {
            root.service.setDuration(next)

            root.currentDuration =
                Number(
                    root.service.duration
                )
        }
    }

    Text {
        text: "WALLPAPER SETTINGS"

        color:
            Theme.accent

        font.family:
            Theme.fontFamily

        font.pixelSize: 9

        font.bold: true
    }

    Rectangle {
        width: parent.width
        height: 58
        radius: 8

        color:
            Qt.rgba(
                Theme.surface.r,
                Theme.surface.g,
                Theme.surface.b,
                0.30
            )

        Row {
            anchors.fill: parent

            anchors.leftMargin: 10
            anchors.rightMargin: 8

            spacing: 8

            Text {
                width: 24

                anchors.verticalCenter:
                    parent.verticalCenter

                text: "󰉖"

                color:
                    Theme.accent

                font.family:
                    Theme.fontFamily

                font.pixelSize: 15
            }

            Column {
                width:
                    parent.width -
                    24 -
                    42 -
                    16 -
                    8

                anchors.verticalCenter:
                    parent.verticalCenter

                spacing: 2

                Text {
                    text:
                        "Wallpaper Folder"

                    color:
                        Theme.subtext

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 9
                }

                TextField {
                    id: folderInput

                    width:
                        parent.width

                    height: 24

                    text:
                        root.service
                        ? root.service.wallpaperDir
                        : ""

                    color:
                        Theme.foreground

                    selectionColor:
                        Theme.accent

                    selectedTextColor:
                        Theme.background

                    placeholderText:
                        "~/Pictures/Wallpapers"

                    placeholderTextColor:
                        Theme.muted

                    background:
                        Rectangle {
                            color:
                                "transparent"
                        }

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 9

                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0

                    selectByMouse: true

                    Keys.onReturnPressed: {
                        root.saveFolder()
                    }
                }
            }

            Rectangle {
                width: 42
                height: 32

                anchors.verticalCenter:
                    parent.verticalCenter

                radius: 8

                color:
                    Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0.20
                    )

                Text {
                    anchors.fill: parent

                    text: "SAVE"

                    color:
                        Theme.accent

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 8

                    font.bold: true

                    horizontalAlignment:
                        Text.AlignHCenter

                    verticalAlignment:
                        Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent

                    z: 100

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        root.saveFolder()
                    }
                }
            }
        }
    }

    Row {
        width: parent.width

        spacing: 6

        Rectangle {
            id: transitionCard

            width:
                (parent.width - 6) / 2

            height: 46

            radius: 8

            z: 100

            color:
                transitionMouse.pressed
                ? Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.28
                )
                : Qt.rgba(
                    Theme.surface.r,
                    Theme.surface.g,
                    Theme.surface.b,
                    0.30
                )

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Column {
                anchors.left:
                    parent.left

                anchors.leftMargin: 10

                anchors.verticalCenter:
                    parent.verticalCenter

                spacing: 1

                Text {
                    text:
                        "󰔛  Transition"

                    color:
                        Theme.muted

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 8
                }

                Text {
                    text:
                        root.currentTransition

                    color:
                        Theme.foreground

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 10

                    font.bold: true
                }
            }

            Text {
                anchors.right:
                    parent.right

                anchors.rightMargin: 10

                anchors.verticalCenter:
                    parent.verticalCenter

                text: "󰅂"

                color:
                    Theme.accent

                font.family:
                    Theme.fontFamily

                font.pixelSize: 14
            }

            MouseArea {
                id: transitionMouse

                anchors.fill: parent

                z: 1000

                hoverEnabled: true

                preventStealing: true

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {
                    root.changeTransition()
                }
            }
        }

        Rectangle {
            id: durationCard

            width:
                (parent.width - 6) / 2

            height: 46

            radius: 8

            z: 100

            color:
                durationMouse.pressed
                ? Qt.rgba(
                    Theme.accent.r,
                    Theme.accent.g,
                    Theme.accent.b,
                    0.28
                )
                : Qt.rgba(
                    Theme.surface.r,
                    Theme.surface.g,
                    Theme.surface.b,
                    0.30
                )

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Column {
                anchors.left:
                    parent.left

                anchors.leftMargin: 10

                anchors.verticalCenter:
                    parent.verticalCenter

                spacing: 1

                Text {
                    text:
                        "󰔚  Seconds"

                    color:
                        Theme.muted

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 8
                }

                Text {
                    text:
                        Number(
                            root.currentDuration
                        ).toFixed(1) +
                        "s"

                    color:
                        Theme.foreground

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 10

                    font.bold: true
                }
            }

            Text {
                anchors.right:
                    parent.right

                anchors.rightMargin: 10

                anchors.verticalCenter:
                    parent.verticalCenter

                text: "󰅂"

                color:
                    Theme.accent

                font.family:
                    Theme.fontFamily

                font.pixelSize: 14
            }

            MouseArea {
                id: durationMouse

                anchors.fill: parent

                z: 1000

                hoverEnabled: true

                preventStealing: true

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {
                    root.changeDuration()
                }
            }
        }
    }

    component AutoCard: Rectangle {
        id: ac

        property string label: ""
        property string value: ""
        property bool lit: false

        signal clicked()

        height: 46
        radius: 8
        z: 100

        color: acMouse.pressed
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
            : ac.lit
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.30)

        border.width: ac.lit ? 1 : 0
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: ac.label
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }

            Text {
                text: ac.value
                color: ac.lit ? Theme.accent : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
            }
        }

        MouseArea {
            id: acMouse

            anchors.fill: parent
            z: 1000
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ac.clicked()
        }
    }

    Row {
        width: parent.width
        spacing: 6

        AutoCard {
            width: (parent.width - 18) / 4
            label: "󰁪  Auto change"
            value: root.service && root.service.autoOn ? "ON" : "OFF"
            lit: root.service ? root.service.autoOn : false
            onClicked: if (root.service) root.service.toggleAuto()
        }

        AutoCard {
            width: (parent.width - 18) / 4
            label: "󰔛  Every"
            value: root.service ? root.service.autoLabel(root.service.autoMinutes) : "30 min"
            onClicked: if (root.service) root.service.cycleAutoInterval()
        }

        AutoCard {
            width: (parent.width - 18) / 4
            label: "󰒝  Order"
            value: root.service ? root.service.autoMode : "random"
            onClicked: if (root.service) root.service.cycleAutoMode()
        }

        AutoCard {
            width: (parent.width - 18) / 4
            label: "󰸉  Type"
            value: root.service ? root.service.autoMedia : "all"
            onClicked: if (root.service) root.service.cycleAutoMedia()
        }
    }

    Timer {
        id: serviceSyncTimer

        interval: 100

        repeat: false

        onTriggered: {
            root.syncService()
        }
    }

    onServiceChanged: {
        serviceSyncTimer.restart()
    }

    Component.onCompleted: {
        serviceSyncTimer.restart()
    }
}