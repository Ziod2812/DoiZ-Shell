import QtQuick
import ".."

Column {
    id: root

    spacing: 7

    property int typeFilter: 0
    property string colorFilter: ""
    property bool busy: false
    property var stats: ({
        all: 0,
        image: 0,
        video: 0,
        colors: ({})
    })

    signal typeSelected(int value)
    signal colorSelected(string value)

    readonly property var types: [
        { key: 0, icon: "", label: "All" },
        { key: 1, icon: "󰸉", label: "Wallpaper" },
        { key: 2, icon: "󰎁", label: "Video" }
    ]

    readonly property var palette: [
        { name: "red", value: "#E0475B" },
        { name: "orange", value: "#F08A3C" },
        { name: "yellow", value: "#F2CF4A" },
        { name: "green", value: "#4FBF73" },
        { name: "cyan", value: "#3CC8D6" },
        { name: "blue", value: "#4B7BEC" },
        { name: "purple", value: "#8E5BE0" },
        { name: "pink", value: "#F27FB5" },
        { name: "white", value: "#F2F2F2" },
        { name: "black", value: "#121212" }
    ]

    function typeCount(key) {
        if (key === 1)
            return Number(root.stats.image || 0)

        if (key === 2)
            return Number(root.stats.video || 0)

        return Number(root.stats.all || 0)
    }

    function colorCount(name) {
        return Number(
            (root.stats.colors || ({}))[name] || 0
        )
    }

    Item {
        id: typeWrap

        width: parent.width
        height: 26

        property real pillX: 0
        property real pillW: 0
        property real pillP: 1
        property bool armed: false

        Timer {
            running: true
            interval: 80
            onTriggered: typeWrap.armed = true
        }

        NumberAnimation {
            id: pillPulse

            target: typeWrap
            property: "pillP"
            from: 0
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
        }

        Rectangle {
            id: pill

            x: typeWrap.pillX
            width: typeWrap.pillW
            height: typeWrap.height
            radius: 8
            visible: typeWrap.pillW > 0
            scale: 1 + 0.07 * Math.sin(typeWrap.pillP * Math.PI)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
            border.width: 1
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)

            Behavior on x {
                enabled: typeWrap.armed

                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            Behavior on width {
                enabled: typeWrap.armed

                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
        }

    Row {
        id: typeRow

        width: parent.width
        height: 26

        spacing: 6

        Repeater {
            model: root.types

            delegate: Rectangle {
                id: chip

                required property var modelData

                readonly property bool active:
                    root.typeFilter === modelData.key

                height: typeRow.height
                width: chipLabel.implicitWidth + 24

                radius: 8

                color:
                    chip.active
                    ? Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0
                    )
                    : chipMouse.containsMouse
                        ? Qt.rgba(
                            Theme.accent.r,
                            Theme.accent.g,
                            Theme.accent.b,
                            0.12
                        )
                        : Qt.rgba(
                            Theme.surface.r,
                            Theme.surface.g,
                            Theme.surface.b,
                            0.30
                        )

                border.width: 0

                scale: chipMouse.pressed ? 0.93 : 1

                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                function syncPill() {
                    if (!chip.active)
                        return

                    typeWrap.pillX = chip.x
                    typeWrap.pillW = chip.width
                }

                onActiveChanged: {
                    chip.syncPill()

                    if (chip.active && typeWrap.armed)
                        pillPulse.restart()
                }

                onXChanged: chip.syncPill()
                onWidthChanged: chip.syncPill()
                Component.onCompleted: chip.syncPill()

                border.color:
                    Qt.rgba(
                        Theme.accent.r,
                        Theme.accent.g,
                        Theme.accent.b,
                        0.55
                    )

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    id: chipLabel

                    anchors.centerIn: parent

                    text:
                        (
                            chip.modelData.icon.length > 0
                            ? chip.modelData.icon + "  "
                            : ""
                        ) +
                        chip.modelData.label +
                        "  " +
                        root.typeCount(chip.modelData.key)

                    color:
                        chip.active
                        ? Theme.foreground
                        : Theme.subtext

                    font.family:
                        Theme.fontFamily

                    font.pixelSize: 9

                    font.bold:
                        chip.active
                }

                MouseArea {
                    id: chipMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape:
                        Qt.PointingHandCursor

                    onClicked: {
                        root.typeSelected(
                            chip.modelData.key
                        )
                    }
                }
            }
        }
    }
    }

    Column {
        id: colorRow

        width: parent.width

        spacing: 6

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: "COLOR"

                color:
                    Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 9

                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text:
                    root.colorFilter.length > 0
                    ? root.colorFilter +
                      "  ·  " +
                      root.colorCount(root.colorFilter)
                    : root.busy
                        ? "󰑓  analyzing"
                        : ""

                color:
                    root.colorFilter.length > 0
                    ? Theme.accent
                    : Theme.muted

                font.family:
                    Theme.fontFamily

                font.pixelSize: 9

                font.bold: true
            }
        }

        Row {
            width: parent.width
            height: 26

            spacing: 8

            Repeater {
                model: root.palette

                delegate: Item {
                    id: swatch

                    required property var modelData

                    readonly property bool active:
                        root.colorFilter === modelData.name

                    readonly property int count:
                        root.colorCount(modelData.name)

                    width: 28
                    height: 26

                    opacity:
                        swatch.active || swatch.count > 0
                        ? 1.0
                        : 0.28

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent

                        width:
                            swatch.active
                            ? 24
                            : swatchMouse.containsMouse
                                ? 22
                                : 20

                        height: width

                        radius: width / 2

                        color:
                            swatch.modelData.value

                        border.width:
                            swatch.active
                            ? 2
                            : 1

                        border.color:
                            swatch.active
                            ? Theme.foreground
                            : Qt.rgba(1, 1, 1, 0.22)

                        Behavior on width {
                            NumberAnimation {
                                duration: 90
                            }
                        }
                    }

                    MouseArea {
                        id: swatchMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked: {
                            root.colorSelected(
                                swatch.modelData.name
                            )
                        }
                    }
                }
            }
        }
    }
}
