import QtQuick

Canvas {
    id: glow

    property color tint: "white"
    property real strength: 0.5

    onTintChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var r = width / 2
        var g = ctx.createRadialGradient(r, r, 0, r, r, r)
        g.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, strength))
        g.addColorStop(0.5, Qt.rgba(tint.r, tint.g, tint.b, strength * 0.35))
        g.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0))
        ctx.fillStyle = g
        ctx.fillRect(0, 0, width, height)
    }
}
