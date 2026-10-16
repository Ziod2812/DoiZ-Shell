import QtQuick
import "."

Rectangle {
    id: card

    property bool clickable: false
    property bool selected: false
    property color tone: Theme.accentColor
    property alias hovered: area.containsMouse

    signal clicked()

    radius: 8

    color: card.selected
           ? Theme.tint(card.tone, 0.16)
           : card.clickable && area.containsMouse
             ? Theme.tint(card.tone, 0.18)
             : Theme.cardColor

    border.width: card.selected ? 1 : card.clickable ? 1 : 0
    border.color: card.selected ? Theme.tint(card.tone, 0.7) : Theme.lineColor

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: card.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: card.clicked()
    }
}
