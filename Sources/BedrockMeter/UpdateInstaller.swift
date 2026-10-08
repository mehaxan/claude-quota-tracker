import Cocoa

/// Downloads a release `.dmg`, swaps its app bundle in for the running one, and
/// relaunches. Mirrors what a person doing the "Manual install" from the README
/// would do by hand: mount the dmg, replace `BedrockMeter.app`, reopen it.
///
/// `FileManager.replaceItemAt` is used for the swap because it's an atomic
/// rename - the running process keeps its already-open file handles to the old
/// bundle on disk until it quits, so this is safe to run while the app that's
/// being replaced is still executing.
final class UpdateInstaller {
    enum InstallError: Error, CustomStringConvertible {
        case mountFailed
        case appNotFoundInImage
        case noDownloadedFile

        var description: String {
            switch self {
            case .mountFailed: return "Could not open the downloaded disk image"
            case .appNotFoundInImage: return "The downloaded disk image did not contain BedrockMeter.app"
            case .noDownloadedFile: return "The update did not download correctly"
            }
        }
    }

    func install(from downloadURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: downloadURL) { tempURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let tempURL = tempURL else {
                completion(.failure(InstallError.noDownloadedFile))
                return
            }
            do {
                try self.installDownloadedDMG(at: tempURL)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    private func installDownloadedDMG(at downloadedURL: URL) throws {
        let fileManager = FileManager.default

        let dmgDir = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: downloadedURL, create: true)
        defer { try? fileManager.removeItem(at: dmgDir) }
        let dmgURL = dmgDir.appendingPathComponent("BedrockMeter.dmg")
        try fileManager.moveItem(at: downloadedURL, to: dmgURL)

        let mountPoint = try mount(dmgURL: dmgURL)
        defer { try? detach(mountPoint: mountPoint) }

        let sourceAppURL = mountPoint.appendingPathComponent("BedrockMeter.app")
        guard fileManager.fileExists(atPath: sourceAppURL.path) else {
            throw InstallError.appNotFoundInImage
        }

        // Stage the copy next to the real app (same volume as /Applications) so
        // the final replaceItemAt below is an atomic same-volume rename.
        let destinationAppURL = Bundle.main.bundleURL
        let stagingDir = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destinationAppURL, create: true)
        defer { try? fileManager.removeItem(at: stagingDir) }
        let stagedAppURL = stagingDir.appendingPathComponent("BedrockMeter.app")
        try fileManager.copyItem(at: sourceAppURL, to: stagedAppURL)

        _ = try fileManager.replaceItemAt(destinationAppURL, withItemAt: stagedAppURL)
    }

    private func mount(dmgURL: URL) throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", dmgURL.path, "-nobrowse", "-plist"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        // Read before waiting: hdiutil can block writing to the pipe once its
        // buffer fills, so waiting first risks a deadlock.
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw InstallError.mountFailed }

        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw InstallError.mountFailed
        }
        for entity in entities {
            if let mountPointString = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPointString)
            }
        }
        throw InstallError.mountFailed
    }

    private func detach(mountPoint: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        try process.run()
        process.waitUntilExit()
    }
}
