import Foundation
import os

private let log = Logger(subsystem: "dev.hobby.bedrock-meter", category: "config")

/// Resolves the credential-process binary path, AWS profile, and refresh interval to
/// use, so other installs of this app can point at a different setup without recompiling.
/// Precedence: environment variables > ~/Library/Application Support config file > defaults.
public struct QuotaConfig {
    public let binaryPath: String
    public let profile: String
    public let refreshInterval: TimeInterval

    public static let defaultRefreshInterval: TimeInterval = 15 * 60
    /// Floor on the refresh interval so a bad config can't hammer credential-process.
    public static let minimumRefreshInterval: TimeInterval = 60

    private struct FileConfig: Codable {
        let binaryPath: String?
        let profile: String?
        let refreshIntervalSeconds: Double?
    }

    public init(binaryPath: String, profile: String, refreshInterval: TimeInterval) {
        self.binaryPath = binaryPath
        self.profile = profile
        self.refreshInterval = refreshInterval
    }

    public static func load() -> QuotaConfig {
        var binaryPath = expandPath("~/claude-code-with-bedrock/credential-process")
        var profile = "oec-prod-us-east-1"
        var refreshInterval = defaultRefreshInterval

        if let fileConfig = loadFileConfig() {
            binaryPath = fileConfig.binaryPath.map(expandPath) ?? binaryPath
            profile = fileConfig.profile ?? profile
            if let seconds = fileConfig.refreshIntervalSeconds {
                refreshInterval = max(seconds, minimumRefreshInterval)
            }
        }

        let environment = ProcessInfo.processInfo.environment
        binaryPath = environment["CLAUDE_QUOTA_BINARY"].map(expandPath) ?? binaryPath
        profile = environment["CLAUDE_QUOTA_PROFILE"] ?? profile
        if let secondsString = environment["CLAUDE_QUOTA_REFRESH_INTERVAL"], let seconds = Double(secondsString) {
            refreshInterval = max(seconds, minimumRefreshInterval)
        }

        return QuotaConfig(binaryPath: binaryPath, profile: profile, refreshInterval: refreshInterval)
    }

    public static func save(binaryPath: String, profile: String, refreshInterval: TimeInterval) throws {
        guard let url = configFileURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let clampedInterval = max(refreshInterval, minimumRefreshInterval)
        let data = try JSONEncoder().encode(
            FileConfig(binaryPath: expandPath(binaryPath), profile: profile, refreshIntervalSeconds: clampedInterval)
        )
        try data.write(to: url, options: .atomic)
        // Config only ever holds local file paths and an AWS profile name, but it's still
        // the one place another local process could redirect what we execute on a timer,
        // so keep it unreadable/unwritable by anyone else.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private static func configFileURL() -> URL? {
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportDir.appendingPathComponent("BedrockMeter/config.json")
    }

    /// Refuses a config file this process doesn't own, so another local account (or a
    /// process that merely wrote the file without matching ownership) can't redirect
    /// which binary we execute on a timer.
    private static func loadFileConfig() -> FileConfig? {
        guard let url = configFileURL() else { return nil }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        guard let ownerID = attributes[.ownerAccountID] as? NSNumber, ownerID.uint32Value == getuid() else {
            log.error("ignoring config file not owned by current user: \(url.path, privacy: .public)")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(FileConfig.self, from: data)
        } catch {
            log.error("ignoring unparseable config file: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
