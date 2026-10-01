import Cocoa

/// A rounded, color-graded progress bar: green under 50%, orange 50-80%, red above.
final class QuotaProgressView: NSView {
    var percent: Double = 0 {
        didSet { needsDisplay = true }
    }

    private let barHeight: CGFloat = 7

    private static let trackColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.16)
            : NSColor(white: 0.0, alpha: 0.12)
    }

    static func color(forPercent percent: Double) -> NSColor {
        switch percent {
        case ..<50: return .systemGreen
        case 50..<80: return .systemOrange
        default: return .systemRed
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let barRect = NSRect(x: 0, y: (bounds.height - barHeight) / 2, width: bounds.width, height: barHeight)
        let trackPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        Self.trackColor.setFill()
        trackPath.fill()

        let clamped = max(0, min(percent, 100))
        guard clamped > 0 else { return }

        let fillWidth = max(barHeight, barRect.width * CGFloat(clamped / 100))
        let fillRect = NSRect(x: 0, y: barRect.minY, width: fillWidth, height: barHeight)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barHeight / 2, yRadius: barHeight / 2)

        let base = Self.color(forPercent: clamped)
        let gradient = NSGradient(starting: base.blended(withFraction: 0.3, of: .white) ?? base, ending: base)

        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()
        gradient?.draw(in: fillPath, angle: 90)
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// Custom menu row showing "$used of $limit" / percent above a progress bar.
final class QuotaDetailView: NSView {
    private let amountLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let progressView = QuotaProgressView()

    private static let width: CGFloat = 240
    private static let padding: CGFloat = 14

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 52))

        amountLabel.font = .systemFont(ofSize: 12)
        amountLabel.textColor = .secondaryLabelColor
        amountLabel.lineBreakMode = .byTruncatingTail
        amountLabel.frame = NSRect(x: Self.padding, y: 28, width: 160, height: 16)
        addSubview(amountLabel)

        percentLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: Self.width - Self.padding - 70, y: 28, width: 70, height: 16)
        addSubview(percentLabel)

        progressView.frame = NSRect(x: Self.padding, y: 14, width: Self.width - 2 * Self.padding, height: 7)
        addSubview(progressView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(used: Double, limit: Double, percent: Double) {
        amountLabel.stringValue = String(format: "$%.2f of $%.2f", used, limit)
        percentLabel.stringValue = String(format: "%.1f%%", percent)
        percentLabel.textColor = QuotaProgressView.color(forPercent: percent)
        progressView.percent = percent
    }
}
