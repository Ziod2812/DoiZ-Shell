import QtQuick
import "."

Item {
    id: track

    property real value: 0
    property real from: 0
    property real to: 100
    property color tone: Theme.accentColor
    property bool dragging: false
    property bool interactive: true
    property bool knob: false
    property real wheelStep: 5

    signal moved(real v)

    implicitHeight: 14

    readonly property real ratio:
        Math.max(0, Math.min(1, (track.value - track.from) / (track.to - track.from)))

    Rectangle {
        id: bar

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8
        radius: 4
        color: Theme.trackColor

        Rectangle {
            height: parent.height
            radius: 4
            width: parent.width * track.ratio
            color: track.tone

            Behavior on width {
                enabled: !track.dragging

                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: track.interactive && track.knob
        width: 14
        height: 14
        radius: 7
        x: Math.max(0, Math.min(track.width - width, track.width * track.ratio - width / 2))
        color: track.tone
        border.width: 2
        border.color: Theme.panelColor
    }

    MouseArea {
        anchors.fill: parent
        enabled: track.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function setFromX(x) {
            var r = Math.max(0, Math.min(1, x / track.width))
            track.moved(track.from + r * (track.to - track.from))
        }

        onPressed: (mouse) => {
            track.dragging = true
            setFromX(mouse.x)
        }

        onPositionChanged: (mouse) => {
            if (pressed)
                setFromX(mouse.x)
        }

        onReleased: track.dragging = false
        onCanceled: track.dragging = false

        onWheel: (wheel) => {
            var d = wheel.angleDelta.y > 0 ? track.wheelStep : -track.wheelStep
            track.moved(Math.max(track.from, Math.min(track.to, track.value + d)))
        }
    }
}
