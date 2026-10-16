import QtQuick
import "."

Card {
    id: stat

    property string label: ""
    property string value: "--"

    implicitHeight: 44

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Lbl {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: stat.label
            color: Theme.mutedColor
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Lbl {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: stat.value
            color: stat.tone
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }
}
