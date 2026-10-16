import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: win

    property int page: 0
    property string clock: Qt.formatTime(new Date(), "hh:mm:ss")
    property bool entered: false

    onPageChanged: Theme.typing = false

    signal pageRequested(int index)
    signal closeRequested()

    visible: !Theme.picking
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "doiz-settings-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Timer {
        interval: 16
        running: true

        onTriggered: win.entered = true
    }

    MouseArea {
        anchors.fill: parent

        onClicked: win.closeRequested()
    }

    Rectangle {
        id: frame
        GradBorder {
            rr: 12
            c1: Theme.accentColor
            c2: Qt.lighter(Theme.accentColor, 1.3)
            c3: Theme.accentColor
            c4: Qt.lighter(Theme.accentColor, 1.3)
            cycle: 9000
        }

        width: 860
        height: 560
        anchors.centerIn: parent
        radius: 12
        color: Theme.panelColor
        border.width: 1
        border.color: Theme.tint(Theme.stateColor, 0.35)
        focus: true
        opacity: win.entered ? 1 : 0
        scale: win.entered ? 1 : 0.97

        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        MouseArea {
            anchors.fill: parent
        }

        Keys.onEscapePressed: win.closeRequested()

        Keys.onPressed: (event) => {
            if (Theme.typing)
                return

            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                win.pageRequested((win.page + 1) % Theme.pages.length)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                win.pageRequested((win.page + Theme.pages.length - 1) % Theme.pages.length)
                event.accepted = true
            }
        }

        Timer {
            interval: 1000
            repeat: true
            running: true

            onTriggered: win.clock = Qt.formatTime(new Date(), "hh:mm:ss")
        }

        Item {
            id: topBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            height: 40

            Rectangle {
                id: logoTile

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 8
                color: Theme.tint(Theme.stateColor, 0.16)

                Behavior on color {
                    ColorAnimation {
                        duration: 250
                    }
                }

                GlowLbl {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Theme.pages[win.page].icon
                    color: Theme.stateColor
                    font.pixelSize: 21
                }
            }

            Column {
                anchors.left: logoTile.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Lbl {
                    text: "SETTINGS"
                    color: Theme.titleColor
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

                Lbl {
                    text: Theme.pages[win.page].title
                    color: Theme.stateColor
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }

            Btn {
                id: closeBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                icon: "\uDB80\uDD56"
                iconSize: 18
                tone: Theme.badColor

                onClicked: win.closeRequested()
            }

            Rectangle {
                anchors.right: closeBtn.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 86
                height: 40
                radius: 8
                color: Theme.cardColor

                GlowLbl {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: win.clock
                    color: Theme.stateColor
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
        }

        Rectangle {
            id: topLine

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topBar.bottom
            anchors.topMargin: 10
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 2
            radius: 1

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: Theme.accentColor }
                GradientStop { position: 0.6; color: Theme.toneB }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Column {
            id: side

            x: 12
            y: 74
            width: 168
            spacing: 3

            Repeater {
                model: Theme.pages

                delegate: Rectangle {
                    id: nav

                    required property var modelData
                    required property int index

                    readonly property bool current: win.page === nav.index

                    width: side.width
                    height: 30
                    radius: 8

                    color: nav.current
                           ? Theme.tint(Theme.stateColor, 0.16)
                           : navMouse.containsMouse
                             ? Theme.tint(Theme.accentColor, 0.18)
                             : Theme.cardColor

                    border.width: 1
                    border.color: nav.current ? Theme.tint(Theme.stateColor, 0.7) : Theme.lineColor

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        GlowLbl {
                            live: nav.current
                            width: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: nav.modelData.icon
                            color: nav.current ? Theme.stateColor : Theme.mutedColor
                            font.pixelSize: 15
                        }

                        Lbl {
                            text: nav.modelData.title
                            color: nav.current ? Theme.titleColor : Theme.textColor
                            font.pixelSize: 11
                            font.weight: nav.current ? Font.Bold : Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: navMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: win.pageRequested(nav.index)
                    }
                }
            }
        }

        Rectangle {
            x: 192
            y: 74
            width: 1
            height: parent.height - 86
            color: Theme.lineColor
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.leftMargin: 205
            anchors.rightMargin: 12
            anchors.topMargin: 74
            anchors.bottomMargin: 12

            Item {
                id: pageHead

                readonly property bool needed: !(loader.item && loader.item.hasHero === true)

                width: parent.width
                height: needed ? 52 : 0
                visible: needed

                Rectangle {
                    id: headTile

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 40
                    radius: 8
                    color: Theme.tint(Theme.stateColor, 0.16)

                    Lbl {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Theme.pages[win.page].icon
                        color: Theme.stateColor
                        font.pixelSize: 21
                    }
                }

                Lbl {
                    anchors.left: headTile.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.pages[win.page].title.toUpperCase()
                    color: Theme.titleColor
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }

            Loader {
                id: loader

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pageHead.bottom
                anchors.bottom: parent.bottom
                source: Theme.pages[win.page].file
            }
        }
    }
}
