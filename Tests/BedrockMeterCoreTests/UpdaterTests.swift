import Foundation
import Testing
@testable import BedrockMeterCore

struct UpdaterTests {
    @Test func isNewerDetectsHigherVersion() {
        #expect(Updater.isNewer("v1.2.0", than: "1.1.0"))
        #expect(Updater.isNewer("2.0.0", than: "1.9.9"))
    }

    @Test func isNewerRejectsEqualOrLowerVersion() {
        #expect(!Updater.isNewer("1.1.0", than: "1.1.0"))
        #expect(!Updater.isNewer("v1.1.0", than: "1.1.0"))
        #expect(!Updater.isNewer("1.0.9", than: "1.1.0"))
    }

    @Test func isNewerTreatsMissingComponentsAsZero() {
        #expect(!Updater.isNewer("1.2", than: "1.2.0"))
        #expect(Updater.isNewer("1.2.1", than: "1.2"))
    }

    @Test func parseReleaseReturnsUpdateWhenNewerVersionHasDmgAsset() throws {
        let json = """
        {
            "tag_name": "v1.2.0",
            "html_url": "https://github.com/mehaxan/claude-quota-tracker/releases/tag/v1.2.0",
            "assets": [
                {"name": "BedrockMeter.dmg", "browser_download_url": "https://example.com/BedrockMeter.dmg"}
            ]
        }
        """.data(using: .utf8)!

        let update = try Updater.parseRelease(json, currentVersion: "1.1.0")

        #expect(update?.version == "1.2.0")
        #expect(update?.downloadURL == URL(string: "https://example.com/BedrockMeter.dmg"))
        #expect(update?.releaseURL == URL(string: "https://github.com/mehaxan/claude-quota-tracker/releases/tag/v1.2.0"))
    }

    @Test func parseReleaseReturnsNilWhenAlreadyUpToDate() throws {
        let json = """
        {
            "tag_name": "v1.1.0",
            "html_url": "https://github.com/mehaxan/claude-quota-tracker/releases/tag/v1.1.0",
            "assets": [
                {"name": "BedrockMeter.dmg", "browser_download_url": "https://example.com/BedrockMeter.dmg"}
            ]
        }
        """.data(using: .utf8)!

        let update = try Updater.parseRelease(json, currentVersion: "1.1.0")

        #expect(update == nil)
    }

    @Test func parseReleaseThrowsWhenNoDmgAssetPresent() {
        let json = """
        {
            "tag_name": "v1.2.0",
            "html_url": "https://github.com/mehaxan/claude-quota-tracker/releases/tag/v1.2.0",
            "assets": [
                {"name": "source.zip", "browser_download_url": "https://example.com/source.zip"}
            ]
        }
        """.data(using: .utf8)!

        #expect(throws: UpdateCheckError.noDmgAsset) {
            try Updater.parseRelease(json, currentVersion: "1.1.0")
        }
    }

    @Test func parseReleaseThrowsOnMalformedJSON() {
        let json = "not json".data(using: .utf8)!

        #expect(throws: UpdateCheckError.malformedResponse) {
            try Updater.parseRelease(json, currentVersion: "1.1.0")
        }
    }
}
