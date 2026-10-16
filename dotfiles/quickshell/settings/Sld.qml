import QtQuick
import "."

Card {
    id: sld

    property string title: ""
    property string unit: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1

    signal committed(int v)

    height: 52

    Lbl {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 9
        text: sld.title
        color: Theme.titleColor
        font.pixelSize: 11
        font.weight: Font.Bold
    }

    Lbl {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 9
        text: Math.round(local) + sld.unit
        color: Theme.stateColor
        font.pixelSize: 11
        font.weight: Font.Bold
    }

    property real local: sld.value

    onValueChanged: if (!bar.dragging) local = sld.value

    Timer {
        id: debounce

        interval: 250

        onTriggered: sld.committed(Math.round(sld.local))
    }

    Track {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        value: sld.local
        from: sld.from
        to: sld.to
        knob: true
        wheelStep: sld.step

        onMoved: (v) => {
            sld.local = Math.round(v / sld.step) * sld.step
            debounce.restart()
        }
    }
}
