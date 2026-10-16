import QtQuick

Text {
    property string bars: ""

    text: bars
    color: Theme.accent
    font.family: Theme.font
    font.pixelSize: 10
    font.weight: Font.Bold
    font.letterSpacing: 0
    font.kerning: false
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    height: 22
    width: 84
}
