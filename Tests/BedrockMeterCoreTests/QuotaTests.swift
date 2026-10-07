import Testing
@testable import BedrockMeterCore

struct QuotaTests {
    @Test func parseQuotaValidLine() {
        let output = "Monthly: $4.80 / $1,100.00 (0.4%)"
        let result = parseQuota(output)
        #expect(result?.used == 4.80)
        #expect(result?.limit == 1100.00)
        #expect(result?.percent == 0.4)
    }

    @Test func parseQuotaWithSurroundingText() {
        let output = """
        Checking credentials...
        Monthly: $550.25 / $1,100.00 (50.0%)
        Done.
        """
        let result = parseQuota(output)
        #expect(result?.used == 550.25)
        #expect(result?.limit == 1100.00)
        #expect(result?.percent == 50.0)
    }

    @Test func parseQuotaMalformedReturnsNil() {
        #expect(parseQuota("not a quota line at all") == nil)
    }

    @Test func parseQuotaEmptyReturnsNil() {
        #expect(parseQuota("") == nil)
    }

    @Test func quotaErrorDescriptions() {
        #expect(QuotaError.timeout.description.contains("timed out"))
        #expect(QuotaError.launchFailed("boom").description.contains("boom"))
        #expect(QuotaError.parseFailed("").description == "no output from credential-process")
        #expect(QuotaError.parseFailed("garbage").description.contains("garbage"))
    }

    @Test func fetchQuotaFailsForNonExecutablePath() {
        let result = fetchQuota(binaryPath: "/nonexistent/credential-process", profile: "test", timeout: 1)
        switch result {
        case .failure(.launchFailed):
            break
        default:
            Issue.record("expected launchFailed for a missing binary, got \(result)")
        }
    }
}
