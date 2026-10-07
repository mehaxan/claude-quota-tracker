// One-off tool, not part of the app target: renders the 1024x1024 app icon
// master used by scripts/build-icon.sh. Run with: swift scripts/generate-icon.swift <output.png>
import AppKit

func color(forFraction t: CGFloat) -> NSColor {
    let green = NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.44, alpha: 1)
    let orange = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.10, alpha: 1)
    let red = NSColor(calibratedRed: 0.95, green: 0.23, blue: 0.23, alpha: 1)
    if t < 0.5 {
        return green.blended(withFraction: t / 0.5, of: orange) ?? orange
    } else {
        return orange.blended(withFraction: (t - 0.5) / 0.5, of: red) ?? red
    }
}

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    // Background: rounded square, dark navy, subtle top-to-bottom gradient for depth.
    let cornerRadius = size * 0.22
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    let bgGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.10, alpha: 1),
    ])
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    bgGradient?.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Ring gauge: faint full-circle track plus a green->orange->red progress arc.
    let ringInset = size * 0.24
    let ringRect = rect.insetBy(dx: ringInset, dy: ringInset)
    let lineWidth = size * 0.09
    let circleRect = ringRect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

    let trackPath = NSBezierPath(ovalIn: circleRect)
    trackPath.lineWidth = lineWidth
    NSColor.white.withAlphaComponent(0.08).setStroke()
    trackPath.stroke()

    let center = NSPoint(x: circleRect.midX, y: circleRect.midY)
    let radius = circleRect.width / 2
    let fraction: CGFloat = 0.72
    let startAngle: CGFloat = 90
    let endAngle = startAngle - fraction * 360

    func point(atDegrees degrees: CGFloat) -> NSPoint {
        let radians = degrees * .pi / 180
        return NSPoint(x: center.x + radius * cos(radians), y: center.y + radius * sin(radians))
    }

    // Draw the arc as many short butt-capped segments with an interpolated
    // stroke color, which approximates an angular gradient (CoreGraphics has
    // no native support for one). Round caps are drawn separately below so
    // the segment joints don't show as bumps.
    let segments = 160
    for i in 0..<segments {
        let t0 = CGFloat(i) / CGFloat(segments)
        let t1 = CGFloat(i + 1) / CGFloat(segments)
        let segment = NSBezierPath()
        segment.appendArc(
            withCenter: center, radius: radius,
            startAngle: startAngle - t0 * fraction * 360,
            endAngle: startAngle - t1 * fraction * 360,
            clockwise: true
        )
        segment.lineWidth = lineWidth
        segment.lineCapStyle = .butt
        color(forFraction: t0).setStroke()
        segment.stroke()
    }

    for (angle, fraction) in [(startAngle, CGFloat(0)), (endAngle, CGFloat(1))] {
        let capRect = NSRect(
            x: point(atDegrees: angle).x - lineWidth / 2,
            y: point(atDegrees: angle).y - lineWidth / 2,
            width: lineWidth, height: lineWidth
        )
        color(forFraction: fraction).setFill()
        NSBezierPath(ovalIn: capRect).fill()
    }

    return true
}

guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else {
    fatalError("couldn't rasterize icon")
}
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("couldn't encode PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-master.png"
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
