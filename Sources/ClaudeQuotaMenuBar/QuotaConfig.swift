import Foundation

/// Resolves the credential-process binary path and profile to use, so other
/// installs of this app can point at a different setup without recompiling.
/// Precedence: environment variables > ~/Library/Application Support config file > defaults.
struct QuotaConfig {
    let binaryPath: String
    let profile: String

    private struct FileConfig: Codable {
        let binaryPath: String?
        let profile: String?
    }

    static func load() -> QuotaConfig {
        var binaryPath = NSString(string: "~/claude-code-with-bedrock/credential-process").expandingTildeInPath
        var profile = "oec-prod-us-east-1"

        if let fileConfig = loadFileConfig() {
            binaryPath = fileConfig.binaryPath.map { NSString(string: $0).expandingTildeInPath } ?? binaryPath
            profile = fileConfig.profile ?? profile
        }

        let environment = ProcessInfo.processInfo.environment
        binaryPath = environment["CLAUDE_QUOTA_BINARY"] ?? binaryPath
        profile = environment["CLAUDE_QUOTA_PROFILE"] ?? profile

        return QuotaConfig(binaryPath: binaryPath, profile: profile)
    }

    static func save(binaryPath: String, profile: String) throws {
        guard let url = configFileURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(FileConfig(binaryPath: binaryPath, profile: profile))
        try data.write(to: url, options: .atomic)
    }

    private static func configFileURL() -> URL? {
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportDir.appendingPathComponent("ClaudeQuotaMenuBar/config.json")
    }

    private static func loadFileConfig() -> FileConfig? {
        guard let url = configFileURL(), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FileConfig.self, from: data)
    }
}
