import QtQuick
import "."

Card {
    id: sw

    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool checked: false
    property color activeTone: Theme.goodColor

    signal toggled()

    height: 52
    clickable: true
    tone: sw.checked ? sw.activeTone : Theme.accentColor

    onClicked: sw.toggled()

    Lbl {
        id: ic

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: sw.icon
        color: sw.checked ? sw.activeTone : Theme.mutedColor
        font.pixelSize: 19
    }

    Column {
        anchors.left: ic.right
        anchors.leftMargin: 12
        anchors.right: pill.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Lbl {
            width: parent.width
            text: sw.title
            color: Theme.titleColor
            font.pixelSize: 11
            font.weight: Font.Bold
        }

        Lbl {
            width: parent.width
            visible: sw.sub !== ""
            text: sw.sub
            color: Theme.mutedColor
            font.pixelSize: 8
        }
    }

    Rectangle {
        id: pill

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 20
        radius: 10
        color: sw.checked ? Theme.tint(sw.activeTone, 0.35) : Theme.trackColor
        border.width: 1
        border.color: sw.checked ? sw.activeTone : Theme.lineColor

        Rectangle {
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            width: 14
            height: 14
            radius: 7
            color: sw.checked ? sw.activeTone : Theme.mutedColor

            Behavior on x {
                NumberAnimation {
                    duration: 120
                }
            }
        }
    }
}
