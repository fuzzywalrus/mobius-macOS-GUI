import Foundation

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case serverName
    case description
    case fileRoot
    case banner
    case agreement
    case network
    case trackers
    case news
    case limits
    case accounts
    case done

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .serverName: return "Server Name"
        case .description: return "Description"
        case .fileRoot: return "File Root"
        case .banner: return "Banner"
        case .agreement: return "Login Agreement"
        case .network: return "Network"
        case .trackers: return "Trackers"
        case .news: return "News"
        case .limits: return "Limits"
        case .accounts: return "Accounts"
        case .done: return "Ready"
        }
    }

    var isSkippable: Bool {
        switch self {
        case .banner, .agreement, .news, .limits: return true
        default: return false
        }
    }

    var next: WizardStep? {
        WizardStep(rawValue: rawValue + 1)
    }

    var previous: WizardStep? {
        WizardStep(rawValue: rawValue - 1)
    }

    static var totalSteps: Int { allCases.count }
}

struct WizardDraft {
    // General
    var serverName: String = "My Hotline Server"
    var serverDescription: String = "A Hotline server powered by Mobius, running on a Mac."
    var fileRoot: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Public").path

    // Banner
    var useDefaultBanner: Bool = true
    var bannerSourceURL: URL? = nil
    var bannerFilename: String = ""

    // Agreement
    var agreementText: String = "Welcome to this Hotline server!\n\nBe kind, don't be a jerk, and have fun."

    // Network
    var serverPort: Int = 5500
    var enableBonjour: Bool = false

    // Trackers
    var enableTrackerRegistration: Bool = true
    var trackerOptions: [TrackerOption] = TrackerOption.defaults

    // News
    var newsDateFormat: String = "Jan02 15:04"
    var newsDelimiter: String = "__________________________________________________________"

    // Limits
    var maxDownloads: Int = 0
    var maxDownloadsPerClient: Int = 0
    var maxConnectionsPerIP: Int = 0

    // Accounts
    var adminPassword: String = ""
    var changeAdminPassword: Bool = false

    /// Returns the list of enabled tracker addresses.
    var enabledTrackers: [String] {
        trackerOptions.filter(\.enabled).map(\.address)
    }
}

struct TrackerOption: Identifiable {
    let address: String
    var enabled: Bool

    var id: String { address }

    static let defaults: [TrackerOption] = [
        TrackerOption(address: "hltracker.com:5499", enabled: true),
        TrackerOption(address: "tracker.preterhuman.net:5499", enabled: true),
        TrackerOption(address: "saddle.dyndns.org:5499", enabled: false),
        TrackerOption(address: "hotline.kicks-ass.net:5499", enabled: false),
    ]
}
