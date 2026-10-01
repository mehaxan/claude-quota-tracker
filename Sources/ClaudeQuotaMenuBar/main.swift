import Cocoa

let refreshInterval: TimeInterval = 15 * 60
let processTimeout: TimeInterval = 20

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var progressMenuItem: NSMenuItem!
    private var quotaDetailView: QuotaDetailView!
    private var errorMenuItem: NSMenuItem!
    private var updatedMenuItem: NSMenuItem!
    private var timer: Timer?
    private var binaryPath: String
    private var profile: String
    private let settingsWindowController = SettingsWindowController()

    override init() {
        let config = QuotaConfig.load()
        binaryPath = config.binaryPath
        profile = config.profile
        super.init()
    }
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "…"

        let menu = NSMenu()

        quotaDetailView = QuotaDetailView()
        progressMenuItem = NSMenuItem()
        progressMenuItem.view = quotaDetailView
        progressMenuItem.isHidden = true
        menu.addItem(progressMenuItem)

        errorMenuItem = NSMenuItem(title: "Checking usage…", action: nil, keyEquivalent: "")
        errorMenuItem.isEnabled = false
        menu.addItem(errorMenuItem)

        updatedMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        updatedMenuItem.isEnabled = false
        menu.addItem(updatedMenuItem)

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        settingsWindowController.onSave = { [weak self] newBinaryPath, newProfile in
            self?.applySettings(binaryPath: newBinaryPath, profile: newProfile)
        }
        settingsWindowController.show(binaryPath: binaryPath, profile: profile)
    }

    private func applySettings(binaryPath: String, profile: String) {
        self.binaryPath = binaryPath
        self.profile = profile
        try? QuotaConfig.save(binaryPath: binaryPath, profile: profile)
        refresh()
    }

    private func refresh() {
        statusItem.button?.title = "⏳"
        let currentBinaryPath = binaryPath
        let currentProfile = profile
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = fetchQuota(binaryPath: currentBinaryPath, profile: currentProfile, timeout: processTimeout)
            DispatchQueue.main.async {
                self?.apply(result)
            }
        }
    }

    private func apply(_ result: Result<QuotaResult, QuotaError>) {
        switch result {
        case .success(let quota):
            if let button = statusItem.button {
                button.image = QuotaMenuBarIcon.circle(percent: quota.percent)
                button.imagePosition = .imageLeading
                button.title = String(format: " %.1f%%", quota.percent)
            }
            quotaDetailView.update(used: quota.used, limit: quota.limit, percent: quota.percent)
            progressMenuItem.isHidden = false
            errorMenuItem.isHidden = true
            updatedMenuItem.title = "Updated \(timeFormatter.string(from: Date()))"
        case .failure(let error):
            statusItem.button?.image = nil
            statusItem.button?.title = "⚠️"
            errorMenuItem.title = error.description
            errorMenuItem.isHidden = false
            progressMenuItem.isHidden = true
            updatedMenuItem.title = "Last attempt \(timeFormatter.string(from: Date()))"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
