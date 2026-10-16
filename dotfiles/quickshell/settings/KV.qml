import QtQuick
import "."

Item {
    id: kv

    property string label: ""
    property string value: "--"
    property color tone: Theme.titleColor

    implicitHeight: 14

    Lbl {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: kv.label
        color: Theme.mutedColor
        font.pixelSize: 8
        font.weight: Font.DemiBold
        font.letterSpacing: 1
    }

    Lbl {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: kv.value
        color: kv.tone
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }
}
