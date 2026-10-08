import Cocoa
import BedrockMeterCore

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

/// Custom menu row showing "$used of $limit" / percent above a progress bar,
/// plus the remaining balance and a same-month pace projection below it.
/// Clicking the row copies the summary to the clipboard.
final class QuotaDetailView: NSView {
    private let amountLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let progressView = QuotaProgressView()
    private let remainingLabel = NSTextField(labelWithString: "")
    private let projectionLabel = NSTextField(labelWithString: "")

    private static let width: CGFloat = 240
    private static let padding: CGFloat = 14

    private static let projectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var copyText = ""
    private var revertWorkItem: DispatchWorkItem?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 90))

        amountLabel.font = .systemFont(ofSize: 12)
        amountLabel.textColor = .secondaryLabelColor
        amountLabel.lineBreakMode = .byTruncatingTail
        amountLabel.frame = NSRect(x: Self.padding, y: 66, width: 160, height: 16)
        addSubview(amountLabel)

        percentLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        percentLabel.alignment = .right
        percentLabel.frame = NSRect(x: Self.width - Self.padding - 70, y: 66, width: 70, height: 16)
        addSubview(percentLabel)

        progressView.frame = NSRect(x: Self.padding, y: 52, width: Self.width - 2 * Self.padding, height: 7)
        addSubview(progressView)

        remainingLabel.font = .systemFont(ofSize: 11)
        remainingLabel.textColor = .secondaryLabelColor
        remainingLabel.frame = NSRect(x: Self.padding, y: 32, width: Self.width - 2 * Self.padding, height: 14)
        addSubview(remainingLabel)

        projectionLabel.font = .systemFont(ofSize: 11)
        projectionLabel.textColor = .tertiaryLabelColor
        projectionLabel.frame = NSRect(x: Self.padding, y: 14, width: Self.width - 2 * Self.padding, height: 14)
        addSubview(projectionLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        revertWorkItem?.cancel()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copyText, forType: .string)

        let previousAmount = amountLabel.stringValue
        amountLabel.stringValue = "Copied to clipboard"
        let workItem = DispatchWorkItem { [weak self] in
            self?.amountLabel.stringValue = previousAmount
        }
        revertWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    func update(used: Double, limit: Double, percent: Double) {
        amountLabel.stringValue = String(format: "$%.2f of $%.2f", used, limit)
        percentLabel.stringValue = String(format: "%.1f%%", percent)
        percentLabel.textColor = QuotaProgressView.color(forPercent: percent)
        progressView.percent = percent
        copyText = String(format: "$%.2f of $%.2f (%.1f%%)", used, limit, percent)

        let remaining = max(0, limit - used)
        remainingLabel.stringValue = String(format: "$%.2f remaining", remaining)

        let projection = projectUsage(used: used, limit: limit)
        if let limitDate = projection.projectedLimitDate {
            projectionLabel.stringValue = "On pace to hit limit around \(Self.projectionDateFormatter.string(from: limitDate))"
        } else {
            projectionLabel.stringValue = String(format: "On pace for $%.0f by month end", projection.projectedMonthTotal)
        }
    }
}

/// Custom menu row for quota-fetch failures, styled to match QuotaDetailView
/// (same padding/font) instead of a plain disabled menu item.
final class ErrorDetailView: NSView {
    private let messageLabel: NSTextField

    private static let width: CGFloat = 240
    private static let padding: CGFloat = 14
    private static let height: CGFloat = 48

    init() {
        messageLabel = NSTextField(wrappingLabelWithString: "")
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))

        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .systemRed
        messageLabel.frame = NSRect(x: Self.padding, y: 4, width: Self.width - 2 * Self.padding, height: Self.height - 8)
        addSubview(messageLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(message: String, isError: Bool = true) {
        messageLabel.stringValue = message
        messageLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }
}
