import Cocoa
import BedrockMeterCore

/// A small window letting the user override the credential-process path, AWS
/// profile, and refresh interval without recompiling. Persists via QuotaConfig.save
/// on "Save".
final class SettingsWindowController: NSWindowController {
    private let binaryPathField = NSTextField(string: "")
    private let profileField = NSTextField(string: "")
    private let refreshIntervalField = NSTextField(string: "")

    var onSave: ((String, String, TimeInterval) -> Void)?

    convenience init() {
        let width: CGFloat = 440
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 228),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BedrockMeter Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI(width: width)
    }

    private func buildUI(width: CGFloat) {
        guard let contentView = window?.contentView else { return }

        let binaryLabel = NSTextField(labelWithString: "credential-process path:")
        binaryLabel.frame = NSRect(x: 20, y: 186, width: width - 40, height: 16)
        contentView.addSubview(binaryLabel)

        binaryPathField.frame = NSRect(x: 20, y: 162, width: width - 40, height: 22)
        binaryPathField.placeholderString = "~/claude-code-with-bedrock/credential-process"
        contentView.addSubview(binaryPathField)

        let profileLabel = NSTextField(labelWithString: "AWS profile:")
        profileLabel.frame = NSRect(x: 20, y: 130, width: width - 40, height: 16)
        contentView.addSubview(profileLabel)

        profileField.frame = NSRect(x: 20, y: 106, width: width - 40, height: 22)
        profileField.placeholderString = "oec-prod-us-east-1"
        contentView.addSubview(profileField)

        let refreshLabel = NSTextField(labelWithString: "Refresh every (minutes):")
        refreshLabel.frame = NSRect(x: 20, y: 74, width: width - 40, height: 16)
        contentView.addSubview(refreshLabel)

        refreshIntervalField.frame = NSRect(x: 20, y: 50, width: 80, height: 22)
        refreshIntervalField.placeholderString = "15"
        contentView.addSubview(refreshIntervalField)

        let minimumMinutes = Int(QuotaConfig.minimumRefreshInterval / 60)
        let refreshHint = NSTextField(labelWithString: "minimum \(minimumMinutes) minute\(minimumMinutes == 1 ? "" : "s")")
        refreshHint.textColor = .secondaryLabelColor
        refreshHint.font = .systemFont(ofSize: 11)
        refreshHint.frame = NSRect(x: 108, y: 54, width: width - 128, height: 16)
        contentView.addSubview(refreshHint)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.frame = NSRect(x: width - 192, y: 16, width: 84, height: 28)
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: width - 104, y: 16, width: 84, height: 28)
        contentView.addSubview(saveButton)
    }

    func show(binaryPath: String, profile: String, refreshInterval: TimeInterval) {
        binaryPathField.stringValue = binaryPath
        profileField.stringValue = profile
        refreshIntervalField.stringValue = String(Int(refreshInterval / 60))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func cancel() {
        window?.close()
    }

    @objc private func save() {
        let binaryPath = binaryPathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = profileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let minutesText = refreshIntervalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !binaryPath.isEmpty, !profile.isEmpty, let minutes = Double(minutesText), minutes > 0 else { return }

        let refreshInterval = max(minutes * 60, QuotaConfig.minimumRefreshInterval)
        onSave?(binaryPath, profile, refreshInterval)
        window?.close()
    }
}
