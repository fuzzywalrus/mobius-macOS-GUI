import Foundation

/// Mirrors the Mobius config.yaml structure.
struct ServerConfig: Codable, Equatable {
    var name: String = "My Hotline server"
    var description: String = "A default configured Hotline server running Mobius"
    var bannerFile: String = ""
    var fileRoot: String = "Files"
    var enableTrackerRegistration: Bool = false
    var trackers: [String] = []
    var preserveResourceForks: Bool = false
    var newsDateFormat: String = ""
    var newsDelimiter: String = ""
    var maxDownloads: Int = 0
    var maxDownloadsPerClient: Int = 0
    var maxConnectionsPerIP: Int = 0
    var ignoreFiles: [String] = ["^\\.", "^@"]
    var enableBonjour: Bool = false
    var encoding: String = ""

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case description = "Description"
        case bannerFile = "BannerFile"
        case fileRoot = "FileRoot"
        case enableTrackerRegistration = "EnableTrackerRegistration"
        case trackers = "Trackers"
        case preserveResourceForks = "PreserveResourceForks"
        case newsDateFormat = "NewsDateFormat"
        case newsDelimiter = "NewsDelimiter"
        case maxDownloads = "MaxDownloads"
        case maxDownloadsPerClient = "MaxDownloadsPerClient"
        case maxConnectionsPerIP = "MaxConnectionsPerIP"
        case ignoreFiles = "IgnoreFiles"
        case enableBonjour = "EnableBonjour"
        case encoding = "Encoding"
    }
}
