import Foundation

struct QuotaResult {
    let used: Double
    let limit: Double
    let percent: Double
}

enum QuotaError: Error {
    case launchFailed(String)
    case timeout
    case parseFailed(String)

    var description: String {
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

func parseQuota(_ output: String) -> QuotaResult? {
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
func fetchQuota(binaryPath: String, profile: String, timeout: TimeInterval) -> Result<QuotaResult, QuotaError> {
    guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
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
        return .failure(.timeout)
    }

    let output = String(data: outputData, encoding: .utf8) ?? ""
    guard let result = parseQuota(output) else {
        return .failure(.parseFailed(output))
    }
    return .success(result)
}
