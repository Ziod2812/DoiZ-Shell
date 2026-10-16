import QtQuick
import QtQuick.Effects
import "."

Item {
    id: head

    property string title: ""
    property string info: ""

    implicitHeight: 20

    Rectangle {
        id: icon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: Theme.stateColor
        opacity: 0.45 + 0.55 * Theme.beat

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: Theme.stateColor
            shadowBlur: 1.0
            shadowOpacity: Theme.beat
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }

    Lbl {
        anchors.left: icon.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: head.title
        color: Theme.mutedColor
        font.pixelSize: 9
        font.weight: Font.Bold
        font.letterSpacing: 1
    }

    Lbl {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: head.info
        color: Theme.stateColor
        font.pixelSize: 9
        font.weight: Font.Bold
    }
}
