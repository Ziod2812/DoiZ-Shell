import QtQuick

Item {
    id: chip

    property string text: ""
    property color color: Theme.subtext
    property bool bold: false
    property bool hoverFx: true
    property int fontSize: 11

    readonly property bool hovered: area.containsMouse

    signal clicked(int button)
    signal scrolled(int dy)

    implicitHeight: 22
    implicitWidth: label.implicitWidth + (chip.hoverFx && chip.hovered ? 20 : 12)

    Behavior on implicitWidth {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: chip.hoverFx && chip.hovered ? Theme.accentAlt : "transparent"
        opacity: chip.hoverFx && chip.hovered ? 0.85 : 1

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: chip.text
        color: chip.hoverFx && chip.hovered ? Theme.bg : chip.color
        font.family: Theme.font
        font.pixelSize: chip.fontSize
        font.weight: chip.bold ? Font.Bold : Font.DemiBold
        renderType: Text.NativeRendering

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => chip.clicked(mouse.button)
        onWheel: wheel => chip.scrolled(wheel.angleDelta.y)
    }
}
