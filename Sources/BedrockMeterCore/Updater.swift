import Foundation

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [ReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

public struct UpdateInfo: Equatable {
    public let version: String
    public let downloadURL: URL
    public let releaseURL: URL

    public init(version: String, downloadURL: URL, releaseURL: URL) {
        self.version = version
        self.downloadURL = downloadURL
        self.releaseURL = releaseURL
    }
}

public enum UpdateCheckError: Error, Equatable, CustomStringConvertible {
    case network(String)
    case noDmgAsset
    case malformedResponse

    public var description: String {
        switch self {
        case .network(let message): return "Could not check for updates: \(message)"
        case .noDmgAsset: return "The latest release has no downloadable .dmg"
        case .malformedResponse: return "Could not parse release information from GitHub"
        }
    }
}

/// Checks GitHub Releases for a newer BedrockMeter build and resolves its
/// `.dmg` download URL. There's no appcast or signing key involved - the
/// release pipeline (`release.yml`) already publishes a tagged GitHub release
/// with the dmg attached whenever `Info.plist`'s version is bumped, so that's
/// the source of truth this reads from directly.
public struct Updater {
    public static let releasesAPIURL = URL(string: "https://api.github.com/repos/mehaxan/claude-quota-tracker/releases/latest")!

    /// Compares dotted version strings (an optional leading "v" is ignored),
    /// treating missing components as 0 so "1.2" == "1.2.0".
    public static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = versionParts(remote)
        let localParts = versionParts(local)
        let count = max(remoteParts.count, localParts.count)
        for index in 0..<count {
            let remotePart = index < remoteParts.count ? remoteParts[index] : 0
            let localPart = index < localParts.count ? localParts[index] : 0
            if remotePart != localPart {
                return remotePart > localPart
            }
        }
        return false
    }

    private static func versionParts(_ version: String) -> [Int] {
        var trimmed = Substring(version)
        if trimmed.hasPrefix("v") {
            trimmed = trimmed.dropFirst()
        }
        return trimmed.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// Returns `nil` when already up to date, or throws if the release couldn't
    /// be parsed, or has no `.dmg` asset to update to.
    static func parseRelease(_ data: Data, currentVersion: String) throws -> UpdateInfo? {
        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateCheckError.malformedResponse
        }

        guard isNewer(release.tagName, than: currentVersion) else { return nil }

        guard let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) else {
            throw UpdateCheckError.noDmgAsset
        }

        var version = Substring(release.tagName)
        if version.hasPrefix("v") {
            version = version.dropFirst()
        }
        return UpdateInfo(version: String(version), downloadURL: dmgAsset.browserDownloadURL, releaseURL: release.htmlURL)
    }

    /// Fetches the latest GitHub release and reports an available update, or
    /// `nil` if `currentVersion` is already current.
    public static func checkForUpdate(
        currentVersion: String,
        session: URLSession = .shared,
        completion: @escaping (Result<UpdateInfo?, UpdateCheckError>) -> Void
    ) {
        var request = URLRequest(url: releasesAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            guard let data = data else {
                completion(.failure(.malformedResponse))
                return
            }
            do {
                completion(.success(try parseRelease(data, currentVersion: currentVersion)))
            } catch let updateError as UpdateCheckError {
                completion(.failure(updateError))
            } catch {
                completion(.failure(.malformedResponse))
            }
        }
        task.resume()
    }
}
