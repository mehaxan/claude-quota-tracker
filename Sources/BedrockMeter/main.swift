import Cocoa
import BedrockMeterCore

let processTimeout: TimeInterval = 20
let updateCheckInterval: TimeInterval = 24 * 60 * 60

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var progressMenuItem: NSMenuItem!
    private var quotaDetailView: QuotaDetailView!
    private var errorMenuItem: NSMenuItem!
    private var errorDetailView: ErrorDetailView!
    private var updatedMenuItem: NSMenuItem!
    private var checkForUpdatesMenuItem: NSMenuItem!
    private var timer: Timer?
    private var updateCheckTimer: Timer?
    private var binaryPath: String
    private var profile: String
    private var refreshInterval: TimeInterval
    private let settingsWindowController = SettingsWindowController()
    private let updateInstaller = UpdateInstaller()
    private var isCheckingForUpdates = false

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    override init() {
        let config = QuotaConfig.load()
        binaryPath = config.binaryPath
        profile = config.profile
        refreshInterval = config.refreshInterval
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

        errorDetailView = ErrorDetailView()
        errorDetailView.update(message: "Checking usage…", isError: false)
        errorMenuItem = NSMenuItem()
        errorMenuItem.view = errorDetailView
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

        checkForUpdatesMenuItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesClicked), keyEquivalent: "")
        checkForUpdatesMenuItem.target = self
        menu.addItem(checkForUpdatesMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        refresh()
        scheduleTimer()
        scheduleUpdateChecks()
    }

    private func scheduleTimer() {
        timer?.invalidate()
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

    private func scheduleUpdateChecks() {
        // Give the UI a moment to settle before the first background check.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.checkForUpdates(userInitiated: false)
        }
        updateCheckTimer?.invalidate()
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: updateCheckInterval, repeats: true) { [weak self] _ in
            self?.checkForUpdates(userInitiated: false)
        }
    }

    @objc private func checkForUpdatesClicked() {
        checkForUpdates(userInitiated: true)
    }

    private func checkForUpdates(userInitiated: Bool) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        if userInitiated {
            checkForUpdatesMenuItem.title = "Checking for Updates…"
            checkForUpdatesMenuItem.isEnabled = false
        }

        Updater.checkForUpdate(currentVersion: currentVersion) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCheckingForUpdates = false
                self.checkForUpdatesMenuItem.title = "Check for Updates…"
                self.checkForUpdatesMenuItem.isEnabled = true

                switch result {
                case .success(let update):
                    if let update = update {
                        self.promptToInstall(update)
                    } else if userInitiated {
                        self.showAlert(title: "You're Up to Date", message: "BedrockMeter \(self.currentVersion) is the latest version.")
                    }
                case .failure(let error):
                    if userInitiated {
                        self.showAlert(title: "Update Check Failed", message: error.description)
                    }
                }
            }
        }
    }

    private func promptToInstall(_ update: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "BedrockMeter \(update.version) is available. You're on \(currentVersion). Download and install it now?"
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        installUpdate(update)
    }

    private func installUpdate(_ update: UpdateInfo) {
        statusItem.button?.title = "⬇️"
        updateInstaller.install(from: update.downloadURL) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    let alert = NSAlert()
                    alert.messageText = "Update Installed"
                    alert.informativeText = "BedrockMeter \(update.version) has been installed. Relaunch now to finish updating?"
                    alert.addButton(withTitle: "Relaunch Now")
                    alert.addButton(withTitle: "Later")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        self.updateInstaller.relaunch()
                        return
                    }
                case .failure(let error):
                    let message = (error as? UpdateInstaller.InstallError)?.description ?? error.localizedDescription
                    self.showAlert(title: "Update Failed", message: message)
                }
                self.refresh()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func openSettings() {
        settingsWindowController.onSave = { [weak self] newBinaryPath, newProfile, newRefreshInterval in
            self?.applySettings(binaryPath: newBinaryPath, profile: newProfile, refreshInterval: newRefreshInterval)
        }
        settingsWindowController.show(binaryPath: binaryPath, profile: profile, refreshInterval: refreshInterval)
    }

    private func applySettings(binaryPath: String, profile: String, refreshInterval: TimeInterval) {
        self.binaryPath = NSString(string: binaryPath).expandingTildeInPath
        self.profile = profile
        self.refreshInterval = max(refreshInterval, QuotaConfig.minimumRefreshInterval)
        try? QuotaConfig.save(binaryPath: self.binaryPath, profile: profile, refreshInterval: self.refreshInterval)
        scheduleTimer()
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
            errorDetailView.update(message: error.description)
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
