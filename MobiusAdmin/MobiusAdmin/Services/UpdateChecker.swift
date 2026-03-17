import Foundation

/// Checks GitHub for newer releases of MobiusAdmin.
@Observable
@MainActor
final class UpdateChecker {
    private(set) var latestVersion: String?
    private(set) var updateAvailable = false
    private(set) var releaseURL: URL?
    private(set) var isChecking = false
    private(set) var lastError: String?

    static let githubRepo = "fuzzywalrus/mobius-macOS-GUI"
    static let releasesURL = URL(string: "https://github.com/fuzzywalrus/mobius-macOS-GUI/releases")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil

        Task {
            do {
                let url = URL(string: "https://api.github.com/repos/\(Self.githubRepo)/releases/latest")!
                var request = URLRequest(url: url)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    lastError = "Could not reach GitHub."
                    isChecking = false
                    return
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let remote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                latestVersion = remote
                releaseURL = URL(string: release.htmlURL)
                updateAvailable = isNewer(remote: remote, local: currentVersion)
            } catch {
                lastError = error.localizedDescription
            }
            isChecking = false
        }
    }

    /// Simple semver comparison: returns true if remote > local.
    private func isNewer(remote: String, local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}

private struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
