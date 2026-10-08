import Foundation
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

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func projectUsageUnderBudgetHasNoLimitDate() {
        // Day 10 of a 31-day month, spending $10/day: on pace for $310, nowhere near $1,100.
        let projection = projectUsage(used: 100, limit: 1100, asOf: Self.date(year: 2024, month: 1, day: 10), calendar: Self.utcCalendar)
        #expect(projection.projectedLimitDate == nil)
        #expect(abs(projection.projectedMonthTotal - 310) < 0.01)
    }

    @Test func projectUsageOverBudgetProjectsLimitDate() {
        // Day 10 of a 31-day month, spending $40/day: hits $1,100 on day 28.
        let projection = projectUsage(used: 400, limit: 1100, asOf: Self.date(year: 2024, month: 1, day: 10), calendar: Self.utcCalendar)
        #expect(projection.projectedLimitDate == Self.date(year: 2024, month: 1, day: 28))
        #expect(abs(projection.projectedMonthTotal - 1240) < 0.01)
    }

    @Test func projectUsageWithNoSpendYet() {
        let projection = projectUsage(used: 0, limit: 1100, asOf: Self.date(year: 2024, month: 1, day: 1), calendar: Self.utcCalendar)
        #expect(projection.projectedLimitDate == nil)
        #expect(projection.projectedMonthTotal == 0)
    }
}
