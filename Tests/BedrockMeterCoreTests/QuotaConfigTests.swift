import Foundation
import Testing
@testable import BedrockMeterCore

// Serialized because these tests mutate process-wide environment variables;
// Swift Testing runs tests concurrently by default, which would race.
@Suite(.serialized)
struct QuotaConfigTests {
    private static let envKeys = ["CLAUDE_QUOTA_BINARY", "CLAUDE_QUOTA_PROFILE", "CLAUDE_QUOTA_REFRESH_INTERVAL"]

    private func withCleanEnvironment(_ body: () -> Void) {
        for key in Self.envKeys {
            unsetenv(key)
        }
        defer {
            for key in Self.envKeys {
                unsetenv(key)
            }
        }
        body()
    }

    @Test func environmentOverridesTakePrecedence() {
        withCleanEnvironment {
            setenv("CLAUDE_QUOTA_BINARY", "/usr/bin/true", 1)
            setenv("CLAUDE_QUOTA_PROFILE", "test-profile", 1)
            setenv("CLAUDE_QUOTA_REFRESH_INTERVAL", "300", 1)

            let config = QuotaConfig.load()

            #expect(config.binaryPath == "/usr/bin/true")
            #expect(config.profile == "test-profile")
            #expect(config.refreshInterval == 300)
        }
    }

    @Test func environmentBinaryPathExpandsTilde() {
        withCleanEnvironment {
            setenv("CLAUDE_QUOTA_BINARY", "~/credential-process", 1)

            let config = QuotaConfig.load()

            #expect(!config.binaryPath.contains("~"))
            #expect(config.binaryPath.hasSuffix("/credential-process"))
        }
    }

    @Test func refreshIntervalIsClampedToMinimum() {
        withCleanEnvironment {
            setenv("CLAUDE_QUOTA_REFRESH_INTERVAL", "10", 1)

            let config = QuotaConfig.load()

            #expect(config.refreshInterval == QuotaConfig.minimumRefreshInterval)
        }
    }

    @Test func defaultRefreshIntervalConstantIsFifteenMinutes() {
        #expect(QuotaConfig.defaultRefreshInterval == 15 * 60)
    }
}
