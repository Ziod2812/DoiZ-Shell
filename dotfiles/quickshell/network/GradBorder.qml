import QtQuick

Item {
    id: gb

    property real rr: 12
    property color c1: "white"
    property color c2: "white"
    property color c3: "white"
    property color c4: "white"
    property int cycle: 9000

    anchors.fill: parent

    Item {
        x: gb.rr
        y: 0
        width: parent.width - gb.rr * 2
        height: 1.5
        clip: true

        Rectangle {
            id: topBand

            height: parent.height
            width: parent.width * 2

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: gb.c1 }
                GradientStop { position: 0.125; color: gb.c2 }
                GradientStop { position: 0.25; color: gb.c3 }
                GradientStop { position: 0.375; color: gb.c4 }
                GradientStop { position: 0.5; color: gb.c1 }
                GradientStop { position: 0.625; color: gb.c2 }
                GradientStop { position: 0.75; color: gb.c3 }
                GradientStop { position: 0.875; color: gb.c4 }
                GradientStop { position: 1.0; color: gb.c1 }
            }

            NumberAnimation on x { from: 0; to: -topBand.width / 2; duration: gb.cycle; loops: Animation.Infinite }
        }
    }

    Item {
        x: gb.rr
        y: parent.height - 1.5
        width: parent.width - gb.rr * 2
        height: 1.5
        clip: true

        Rectangle {
            id: botBand

            height: parent.height
            width: parent.width * 2

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: gb.c3 }
                GradientStop { position: 0.125; color: gb.c4 }
                GradientStop { position: 0.25; color: gb.c1 }
                GradientStop { position: 0.375; color: gb.c2 }
                GradientStop { position: 0.5; color: gb.c3 }
                GradientStop { position: 0.625; color: gb.c4 }
                GradientStop { position: 0.75; color: gb.c1 }
                GradientStop { position: 0.875; color: gb.c2 }
                GradientStop { position: 1.0; color: gb.c3 }
            }

            NumberAnimation on x { from: -botBand.width / 2; to: 0; duration: gb.cycle; loops: Animation.Infinite }
        }
    }

    Rectangle {
        x: 0
        y: gb.rr
        width: 1.5
        height: parent.height - gb.rr * 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: gb.c1 }
            GradientStop { position: 1.0; color: gb.c4 }
        }
    }

    Rectangle {
        x: parent.width - 1.5
        y: gb.rr
        width: 1.5
        height: parent.height - gb.rr * 2

        gradient: Gradient {
            GradientStop { position: 0.0; color: gb.c2 }
            GradientStop { position: 1.0; color: gb.c3 }
        }
    }
}
