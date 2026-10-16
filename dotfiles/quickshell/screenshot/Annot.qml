import QtQuick

Canvas {
    id: cv

    property var strokes: []
    property var live: null
    property real nw: 1

    onStrokesChanged: requestPaint()
    onLiveChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function trace(ctx, p, k) {
        ctx.moveTo(p[0][0] * k, p[0][1] * k)

        if (p.length === 1) {
            ctx.lineTo(p[0][0] * k + 0.01, p[0][1] * k)
            return
        }

        if (p.length === 2) {
            ctx.lineTo(p[1][0] * k, p[1][1] * k)
            return
        }

        for (var j = 1; j < p.length - 1; j++) {
            var mx = (p[j][0] + p[j + 1][0]) / 2
            var my = (p[j][1] + p[j + 1][1]) / 2
            ctx.quadraticCurveTo(p[j][0] * k, p[j][1] * k, mx * k, my * k)
        }

        var l = p[p.length - 1]
        ctx.lineTo(l[0] * k, l[1] * k)
    }

    function rng(seed) {
        var s = (seed >>> 0) || 1

        return function() {
            s = (s * 1664525 + 1013904223) >>> 0
            return s / 4294967296
        }
    }

    function spray(ctx, s, k) {
        var p = s.pts
        var r = s.w * 1.8 * k
        var step = Math.max(1, r * 0.35)
        var rnd = cv.rng(s.seed)
        var dot = Math.max(0.8, s.w * 0.16 * k)
        var n = Math.max(6, Math.round(r * 0.9))

        function puff(x, y) {
            for (var i = 0; i < n; i++) {
                var a = rnd() * Math.PI * 2
                var d = Math.sqrt(rnd()) * r

                ctx.fillRect(x + Math.cos(a) * d, y + Math.sin(a) * d, dot, dot)
            }
        }

        puff(p[0][0] * k, p[0][1] * k)

        for (var j = 1; j < p.length; j++) {
            var x0 = p[j - 1][0] * k
            var y0 = p[j - 1][1] * k
            var dx = p[j][0] * k - x0
            var dy = p[j][1] * k - y0
            var len = Math.sqrt(dx * dx + dy * dy)
            var cnt = Math.max(1, Math.ceil(len / step))

            for (var t = 1; t <= cnt; t++)
                puff(x0 + dx * t / cnt, y0 + dy * t / cnt)
        }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)

        var k = width / Math.max(1, nw)
        var all = strokes.slice()

        if (live)
            all.push(live)

        for (var i = 0; i < all.length; i++) {
            var s = all[i]
            var p = s.pts

            if (!p || p.length === 0)
                continue

            var a = p[0]
            var b = p[p.length - 1]

            ctx.save()
            ctx.strokeStyle = s.color
            ctx.fillStyle = s.color
            ctx.lineWidth = s.w * k
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.globalAlpha = 1
            ctx.globalCompositeOperation = "source-over"
            ctx.beginPath()

            if (s.tool === "pen") {
                cv.trace(ctx, p, k)
                ctx.stroke()
            } else if (s.tool === "marker") {
                ctx.globalAlpha = 0.72
                ctx.lineWidth = s.w * 1.6 * k
                cv.trace(ctx, p, k)
                ctx.stroke()
            } else if (s.tool === "hl") {
                ctx.globalAlpha = 0.38
                ctx.lineWidth = s.w * 3 * k
                ctx.lineCap = "butt"
                ctx.lineJoin = "bevel"
                cv.trace(ctx, p, k)
                ctx.stroke()
            } else if (s.tool === "neon") {
                ctx.shadowColor = s.color
                ctx.shadowBlur = Math.max(4, s.w * 2.4 * k)
                cv.trace(ctx, p, k)
                ctx.stroke()
                ctx.stroke()
                ctx.shadowBlur = 0
                ctx.strokeStyle = "#ffffff"
                ctx.globalAlpha = 0.9
                ctx.lineWidth = Math.max(1, s.w * 0.38 * k)
                ctx.beginPath()
                cv.trace(ctx, p, k)
                ctx.stroke()
            } else if (s.tool === "spray") {
                cv.spray(ctx, s, k)
            } else if (s.tool === "eraser") {
                ctx.globalCompositeOperation = "destination-out"
                ctx.strokeStyle = "#000000"
                ctx.lineWidth = s.w * 2.2 * k
                cv.trace(ctx, p, k)
                ctx.stroke()
            } else if (s.tool === "line") {
                ctx.moveTo(a[0] * k, a[1] * k)
                ctx.lineTo(b[0] * k, b[1] * k)
                ctx.stroke()
            } else if (s.tool === "rect") {
                ctx.rect(
                    Math.min(a[0], b[0]) * k,
                    Math.min(a[1], b[1]) * k,
                    Math.abs(b[0] - a[0]) * k,
                    Math.abs(b[1] - a[1]) * k
                )
                ctx.stroke()
            } else if (s.tool === "oval") {
                ctx.ellipse(
                    Math.min(a[0], b[0]) * k,
                    Math.min(a[1], b[1]) * k,
                    Math.max(0.01, Math.abs(b[0] - a[0]) * k),
                    Math.max(0.01, Math.abs(b[1] - a[1]) * k)
                )
                ctx.stroke()
            } else if (s.tool === "arrow") {
                var dx = b[0] - a[0]
                var dy = b[1] - a[1]
                var len = Math.sqrt(dx * dx + dy * dy)

                ctx.moveTo(a[0] * k, a[1] * k)
                ctx.lineTo(b[0] * k, b[1] * k)
                ctx.stroke()

                if (len > 2) {
                    var ang = Math.atan2(dy, dx)
                    var head = Math.max(14, s.w * 4.5)

                    ctx.beginPath()
                    ctx.moveTo(b[0] * k, b[1] * k)
                    ctx.lineTo((b[0] - head * Math.cos(ang - 0.45)) * k, (b[1] - head * Math.sin(ang - 0.45)) * k)
                    ctx.moveTo(b[0] * k, b[1] * k)
                    ctx.lineTo((b[0] - head * Math.cos(ang + 0.45)) * k, (b[1] - head * Math.sin(ang + 0.45)) * k)
                    ctx.stroke()
                }
            }

            ctx.restore()
        }
    }
}
