import Foundation
import os

private let log = Logger(subsystem: "dev.hobby.bedrock-meter", category: "quota")

public struct QuotaResult {
    public let used: Double
    public let limit: Double
    public let percent: Double

    public init(used: Double, limit: Double, percent: Double) {
        self.used = used
        self.limit = limit
        self.percent = percent
    }
}

/// A linear extrapolation of this month's usage, assuming the daily spend rate
/// observed so far (used / days elapsed) holds for the rest of the month.
public struct UsageProjection: Equatable {
    public let projectedMonthTotal: Double
    public let projectedLimitDate: Date?

    public init(projectedMonthTotal: Double, projectedLimitDate: Date?) {
        self.projectedMonthTotal = projectedMonthTotal
        self.projectedLimitDate = projectedLimitDate
    }
}

/// Projects month-end usage and, if the current daily rate would exceed `limit`
/// before the month ends, the date that's expected to happen. There's no
/// persisted usage history to work from, so this is a same-month linear
/// extrapolation from the single `used` data point rather than a real trend.
public func projectUsage(used: Double, limit: Double, asOf date: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> UsageProjection {
    let dayOfMonth = calendar.component(.day, from: date)
    let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    let fractionElapsed = Double(dayOfMonth) / Double(daysInMonth)
    let projectedMonthTotal = fractionElapsed > 0 ? used / fractionElapsed : used

    var projectedLimitDate: Date?
    let dailyRate = used / Double(dayOfMonth)
    if dailyRate > 0, limit > 0 {
        let daysToLimit = limit / dailyRate
        if daysToLimit <= Double(daysInMonth) {
            let projectedDay = min(max(dayOfMonth, Int(daysToLimit.rounded(.up))), daysInMonth)
            var components = calendar.dateComponents([.year, .month], from: date)
            components.day = projectedDay
            projectedLimitDate = calendar.date(from: components)
        }
    }
    return UsageProjection(projectedMonthTotal: projectedMonthTotal, projectedLimitDate: projectedLimitDate)
}

public enum QuotaError: Error {
    case launchFailed(String)
    case timeout
    case parseFailed(String)

    public var description: String {
        switch self {
        case .launchFailed(let message):
            return "couldn't launch credential-process: \(message)"
        case .timeout:
            return "credential-process timed out (likely needs re-authentication; run it manually once)"
        case .parseFailed(let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "no output from credential-process" : "unexpected output: \(trimmed)"
        }
    }
}

/// Matches the "Monthly: $4.80 / $1,100.00 (0.4%)" line printed by `credential-process --show-quota`.
private let quotaLineRegex = try! NSRegularExpression(
    pattern: #"Monthly:\s*\$([\d,]+\.\d+)\s*/\s*\$([\d,]+\.\d+)\s*\(([\d.]+)%\)"#
)

public func parseQuota(_ output: String) -> QuotaResult? {
    let range = NSRange(output.startIndex..., in: output)
    guard let match = quotaLineRegex.firstMatch(in: output, range: range) else { return nil }

    func group(_ index: Int) -> String? {
        guard let r = Range(match.range(at: index), in: output) else { return nil }
        return String(output[r]).replacingOccurrences(of: ",", with: "")
    }

    guard let usedStr = group(1), let limitStr = group(2), let percentStr = group(3),
          let used = Double(usedStr), let limit = Double(limitStr), let percent = Double(percentStr) else {
        return nil
    }
    return QuotaResult(used: used, limit: limit, percent: percent)
}

/// Runs `credential-process --profile <profile> --show-quota` and parses its text output.
/// Suppresses the tool's own browser notification (CCWB_NO_BROWSER_NOTIFICATION) since this
/// runs unattended on a timer and should never pop a browser window.
public func fetchQuota(binaryPath: String, profile: String, timeout: TimeInterval) -> Result<QuotaResult, QuotaError> {
    guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
        log.error("configured credential-process binary is not executable: \(binaryPath, privacy: .public)")
        return .failure(.launchFailed("no executable at \(binaryPath)"))
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: binaryPath)
    process.arguments = ["--profile", profile, "--show-quota"]

    var environment = ProcessInfo.processInfo.environment
    environment["CCWB_NO_BROWSER_NOTIFICATION"] = "1"
    process.environment = environment

    // credential-process prints the quota status page to stderr, not stdout.
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe
    process.standardInput = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        log.error("failed to launch credential-process: \(error.localizedDescription, privacy: .public)")
        return .failure(.launchFailed(error.localizedDescription))
    }

    let readGroup = DispatchGroup()
    readGroup.enter()
    var outputData = Data()
    DispatchQueue.global(qos: .utility).async {
        outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        readGroup.leave()
    }

    if readGroup.wait(timeout: .now() + timeout) == .timedOut {
        process.terminate()
        log.error("credential-process timed out after \(timeout) seconds")
        return .failure(.timeout)
    }

    let output = String(data: outputData, encoding: .utf8) ?? ""
    guard let result = parseQuota(output) else {
        log.error("couldn't parse credential-process output")
        return .failure(.parseFailed(output))
    }
    return .success(result)
}
