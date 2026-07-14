import QtQuick 2.12

Canvas {
    id: icon

    property string name: ""
    property color iconColor: name === "trash-2" ? "#FFD3D3" : (name === "settings" || name === "refresh-cw" || name === "plus" || name === "folder" ? "#B8F2FD" : "#E8F7FF")

    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onNameChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (width <= 0 || height <= 0)
            return

        var scale = Math.min(width, height) / 24
        var offsetX = (width - 24 * scale) / 2
        var offsetY = (height - 24 * scale) / 2
        ctx.save()
        ctx.translate(offsetX, offsetY)
        ctx.scale(scale, scale)
        ctx.strokeStyle = iconColor
        ctx.fillStyle = iconColor
        ctx.lineWidth = 2
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        if (name === "pencil") {
            ctx.beginPath()
            ctx.moveTo(12, 20)
            ctx.lineTo(21, 20)
            ctx.moveTo(16.5, 3.5)
            ctx.bezierCurveTo(17.3, 2.7, 18.7, 2.7, 19.5, 3.5)
            ctx.bezierCurveTo(20.3, 4.3, 20.3, 5.7, 19.5, 6.5)
            ctx.lineTo(7, 19)
            ctx.lineTo(3, 20)
            ctx.lineTo(4, 16)
            ctx.closePath()
            ctx.stroke()
        } else if (name === "settings") {
            ctx.beginPath()
            ctx.arc(12, 12, 3, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            for (var gearIndex = 0; gearIndex < 16; gearIndex++) {
                var gearAngle = -Math.PI / 2 + gearIndex * Math.PI / 8
                var tooth = gearIndex % 2 === 0
                var radius = tooth ? 9 : 7.2
                var pointX = 12 + Math.cos(gearAngle) * radius
                var pointY = 12 + Math.sin(gearAngle) * radius
                if (gearIndex === 0)
                    ctx.moveTo(pointX, pointY)
                else
                    ctx.lineTo(pointX, pointY)
            }
            ctx.closePath()
            ctx.stroke()
        } else if (name === "refresh-cw") {
            ctx.beginPath()
            ctx.arc(12, 12, 9, 0, -2.35, true)
            ctx.lineTo(3, 8)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(3, 3)
            ctx.lineTo(3, 8)
            ctx.lineTo(8, 8)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(12, 12, 9, Math.PI, 0.79, true)
            ctx.lineTo(21, 16)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(16, 16)
            ctx.lineTo(21, 16)
            ctx.lineTo(21, 21)
            ctx.stroke()
        } else if (name === "plus") {
            ctx.beginPath()
            ctx.moveTo(5, 12)
            ctx.lineTo(19, 12)
            ctx.moveTo(12, 5)
            ctx.lineTo(12, 19)
            ctx.stroke()
        } else if (name === "trash-2") {
            ctx.beginPath()
            ctx.moveTo(3, 6)
            ctx.lineTo(21, 6)
            ctx.moveTo(19, 6)
            ctx.lineTo(19, 20)
            ctx.bezierCurveTo(19, 21.1, 18.1, 22, 17, 22)
            ctx.lineTo(7, 22)
            ctx.bezierCurveTo(5.9, 22, 5, 21.1, 5, 20)
            ctx.lineTo(5, 6)
            ctx.moveTo(8, 6)
            ctx.lineTo(8, 4)
            ctx.bezierCurveTo(8, 2.9, 8.9, 2, 10, 2)
            ctx.lineTo(14, 2)
            ctx.bezierCurveTo(15.1, 2, 16, 2.9, 16, 4)
            ctx.lineTo(16, 6)
            ctx.moveTo(10, 11)
            ctx.lineTo(10, 17)
            ctx.moveTo(14, 11)
            ctx.lineTo(14, 17)
            ctx.stroke()
        } else if (name === "grip-vertical") {
            var dots = [[9, 5], [9, 12], [9, 19], [15, 5], [15, 12], [15, 19]]
            for (var dotIndex = 0; dotIndex < dots.length; dotIndex++) {
                ctx.beginPath()
                ctx.arc(dots[dotIndex][0], dots[dotIndex][1], 1.1, 0, Math.PI * 2)
                ctx.fill()
            }
        } else if (name === "folder") {
            ctx.beginPath()
            ctx.moveTo(3, 6)
            ctx.bezierCurveTo(3, 4.9, 3.9, 4, 5, 4)
            ctx.lineTo(10.5, 4)
            ctx.lineTo(12.5, 6)
            ctx.lineTo(19, 6)
            ctx.bezierCurveTo(20.1, 6, 21, 6.9, 21, 8)
            ctx.lineTo(21, 18)
            ctx.bezierCurveTo(21, 19.1, 20.1, 20, 19, 20)
            ctx.lineTo(5, 20)
            ctx.bezierCurveTo(3.9, 20, 3, 19.1, 3, 18)
            ctx.closePath()
            ctx.stroke()
        } else if (name === "x") {
            ctx.beginPath()
            ctx.moveTo(18, 6)
            ctx.lineTo(6, 18)
            ctx.moveTo(6, 6)
            ctx.lineTo(18, 18)
            ctx.stroke()
        }

        ctx.restore()
    }
}
