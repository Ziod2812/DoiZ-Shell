import QtQuick

Item {
    id: mode

    property int current: 0
    property int shown: 0
    property real wheelAcc: 0
    readonly property bool hovered: area.containsMouse
    readonly property var glyphs: ["\uf00a", "\uf0c9", "\uf013"]

    signal activated(int index)

    implicitWidth: 32
    implicitHeight: 22

    function step(dir) {
        mode.slideDir = dir
        mode.current = (mode.current + dir + 3) % 3
    }

    property int slideDir: 1

    onCurrentChanged: swap.restart()

    SequentialAnimation {
        id: swap

        ParallelAnimation {
            NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: 70 }
            NumberAnimation { target: glyph; property: "yOff"; to: -mode.slideDir * 6; duration: 70; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                mode.shown = mode.current
                glyph.yOff = mode.slideDir * 6
            }
        }
        ParallelAnimation {
            NumberAnimation { target: glyph; property: "opacity"; to: 1; duration: 110 }
            NumberAnimation { target: glyph; property: "yOff"; to: 0; duration: 130; easing.type: Easing.OutBack }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: mode.hovered ? Theme.accentAlt : "transparent"
        opacity: mode.hovered ? 0.85 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Column {
        x: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2.5

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 3
                height: 3
                radius: 1.5
                color: mode.hovered ? Theme.bg : (index === mode.current ? Theme.fg : Theme.muted)
                opacity: index === mode.current ? 1 : 0.45

                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }

    Text {
        id: glyph

        property real yOff: 0

        x: 10 + (parent.width - 10 - width) / 2
        y: (parent.height - height) / 2 + yOff
        text: mode.glyphs[mode.shown]
        color: mode.hovered ? Theme.bg : Theme.subtext
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                mode.step(1)
            else
                mode.activated(mode.current)
        }
        onWheel: wheel => {
            mode.wheelAcc += wheel.angleDelta.y
            while (mode.wheelAcc >= 120) {
                mode.wheelAcc -= 120
                mode.step(-1)
            }
            while (mode.wheelAcc <= -120) {
                mode.wheelAcc += 120
                mode.step(1)
            }
        }
    }
}
