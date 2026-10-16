import QtQuick
import "."

Row {
    id: ctl

    property string middleIcon: ""
    property string middleLabel: ""
    property color middleTone: Theme.accentColor
    property bool middleActive: false
    property bool showMiddle: true
    property color tone: Theme.accentColor

    signal minus()
    signal plus()
    signal middle()

    spacing: 6
    height: 44

    readonly property int cells: ctl.showMiddle ? 3 : 2
    readonly property real cellWidth: (ctl.width - (ctl.cells - 1) * 6) / ctl.cells

    Btn {
        width: ctl.cellWidth
        height: 44
        tone: ctl.tone

        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 2
            radius: 1
            color: Theme.textColor
        }

        onClicked: ctl.minus()
    }

    Btn {
        visible: ctl.showMiddle
        width: ctl.cellWidth
        height: 44
        icon: ctl.middleIcon
        iconSize: 19
        filled: ctl.middleActive
        tone: ctl.middleTone

        onClicked: ctl.middle()
    }

    Btn {
        width: ctl.cellWidth
        height: 44
        tone: ctl.tone

        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 2
            radius: 1
            color: Theme.textColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 14
            radius: 1
            color: Theme.textColor
        }

        onClicked: ctl.plus()
    }
}
