import Cocoa

/// A small window letting the user override the credential-process path and
/// AWS profile without recompiling. Persists via QuotaConfig.save on "Save".
final class SettingsWindowController: NSWindowController {
    private let binaryPathField = NSTextField(string: "")
    private let profileField = NSTextField(string: "")

    var onSave: ((String, String) -> Void)?

    convenience init() {
        let width: CGFloat = 440
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Quota Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI(width: width)
    }

    private func buildUI(width: CGFloat) {
        guard let contentView = window?.contentView else { return }

        let binaryLabel = NSTextField(labelWithString: "credential-process path:")
        binaryLabel.frame = NSRect(x: 20, y: 138, width: width - 40, height: 16)
        contentView.addSubview(binaryLabel)

        binaryPathField.frame = NSRect(x: 20, y: 114, width: width - 40, height: 22)
        binaryPathField.placeholderString = "~/claude-code-with-bedrock/credential-process"
        contentView.addSubview(binaryPathField)

        let profileLabel = NSTextField(labelWithString: "AWS profile:")
        profileLabel.frame = NSRect(x: 20, y: 82, width: width - 40, height: 16)
        contentView.addSubview(profileLabel)

        profileField.frame = NSRect(x: 20, y: 58, width: width - 40, height: 22)
        profileField.placeholderString = "oec-prod-us-east-1"
        contentView.addSubview(profileField)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.frame = NSRect(x: width - 192, y: 16, width: 84, height: 28)
        contentView.addSubview(cancelButton)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: width - 104, y: 16, width: 84, height: 28)
        contentView.addSubview(saveButton)
    }

    func show(binaryPath: String, profile: String) {
        binaryPathField.stringValue = binaryPath
        profileField.stringValue = profile
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
        guard !binaryPath.isEmpty, !profile.isEmpty else { return }
        onSave?(binaryPath, profile)
        window?.close()
    }
}
