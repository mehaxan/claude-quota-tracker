import Cocoa

/// Renders a tiny ring gauge for the menu bar: a faint full-circle track with a
/// color-graded arc (green/orange/red) that sweeps clockwise from the top as
/// usage increases, like a radial progress indicator.
enum QuotaMenuBarIcon {
    static func circle(percent: Double) -> NSImage {
        let diameter: CGFloat = 13
        let lineWidth: CGFloat = 2.0

        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            let circleRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)

            let trackPath = NSBezierPath(ovalIn: circleRect)
            trackPath.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.22).setStroke()
            trackPath.stroke()

            let clamped = max(0, min(percent, 100))
            guard clamped > 0 else { return true }

            let color = QuotaProgressView.color(forPercent: clamped)
            color.setStroke()

            if clamped >= 99.95 {
                trackPath.lineWidth = lineWidth
                let fullPath = NSBezierPath(ovalIn: circleRect)
                fullPath.lineWidth = lineWidth
                fullPath.stroke()
            } else {
                let center = NSPoint(x: circleRect.midX, y: circleRect.midY)
                let radius = circleRect.width / 2
                let fraction = clamped / 100
                let progressPath = NSBezierPath()
                progressPath.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - CGFloat(fraction) * 360, clockwise: true)
                progressPath.lineWidth = lineWidth
                progressPath.lineCapStyle = .round
                progressPath.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
