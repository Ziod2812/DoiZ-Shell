import QtQuick
import "."

Item {
    id: hero

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string badge: ""
    property color tone: Theme.accentColor
    property real value: 0
    property bool showTrack: true
    property bool interactive: true
    property bool knob: false

    signal moved(real v)

    implicitHeight: hero.showTrack ? 62 : 40

    Item {
        id: top

        width: parent.width
        height: 40

        Rectangle {
            id: tile

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 8
            color: Theme.tint(hero.tone, 0.16)

            Behavior on color {
                ColorAnimation {
                    duration: 250
                }
            }

            GlowLbl {
                glowColor: hero.tone
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: hero.icon
                color: hero.tone
                font.pixelSize: 21
            }
        }

        Column {
            anchors.left: tile.right
            anchors.leftMargin: 10
            anchors.right: badgeBox.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Lbl {
                width: parent.width
                text: hero.title
                color: Theme.titleColor
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Lbl {
                width: parent.width
                text: hero.subtitle
                color: hero.tone
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: badgeBox

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: hero.badge !== ""
            width: 54
            height: 40
            radius: 8
            color: Theme.cardColor

            Lbl {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: hero.badge
                color: hero.tone
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }
    }

    Track {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: top.bottom
        anchors.topMargin: 8
        visible: hero.showTrack
        value: hero.value
        tone: hero.tone
        interactive: hero.interactive
        knob: hero.knob

        onMoved: (v) => hero.moved(v)
    }
}
