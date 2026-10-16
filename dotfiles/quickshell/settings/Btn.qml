import QtQuick
import "."

Rectangle {
    id: btn

    property string icon: ""
    property string label: ""
    property color tone: Theme.textColor
    property bool filled: false
    property int iconSize: 15
    property alias hovered: mouse.containsMouse

    signal clicked()

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 36
    radius: 8
    opacity: btn.enabled ? 1 : 0.45

    border.width: 1
    border.color: btn.filled ? Theme.tint(btn.tone, 0.7) : Theme.lineColor

    color: btn.filled
           ? Theme.tint(btn.tone, mouse.containsMouse ? 0.30 : 0.22)
           : mouse.containsMouse
             ? Theme.tint(btn.tone, 0.18)
             : Theme.cardColor

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 7

        Lbl {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            text: btn.icon
            color: btn.tone
            font.pixelSize: btn.iconSize
        }

        Lbl {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.label !== ""
            text: btn.label
            color: btn.filled ? btn.tone : Theme.textColor
            font.pixelSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: btn.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: btn.clicked()
    }
}
