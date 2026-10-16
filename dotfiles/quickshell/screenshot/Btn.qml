import QtQuick

Rectangle {
    id: btn

    property string label: ""
    property bool active: false
    property bool primary: false
    property color tone: "#cba6f7"
    property color fg: "#ebeffa"
    property string fontName: "JetBrainsMono Nerd Font"
    property int pad: 24

    signal clicked()

    implicitWidth: txt.implicitWidth + pad
    implicitHeight: 30
    radius: 8

    color: primary
        ? (area.containsMouse ? Qt.lighter(tone, 1.12) : tone)
        : Qt.rgba(tone.r, tone.g, tone.b, active ? 0.30 : (area.containsMouse ? 0.20 : 0.08))

    border.width: 1
    border.color: Qt.rgba(tone.r, tone.g, tone.b, active ? 0.9 : 0.25)

    Text {
        id: txt

        anchors.centerIn: parent
        text: btn.label
        color: btn.primary ? "#12141f" : btn.fg
        font.family: btn.fontName
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
