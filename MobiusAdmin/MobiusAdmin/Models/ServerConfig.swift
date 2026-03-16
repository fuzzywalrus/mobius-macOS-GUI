import Foundation

/// Mirrors the Mobius config.yaml structure.
struct ServerConfig: Codable, Equatable {
    var Name: String = "My Hotline server"
    var Description: String = "A default configured Hotline server running Mobius"
    var BannerFile: String = ""
    var FileRoot: String = "Files"
    var EnableTrackerRegistration: Bool = false
    var Trackers: [String] = []
    var PreserveResourceForks: Bool = false
    var NewsDateFormat: String = ""
    var NewsDelimiter: String = ""
    var MaxDownloads: Int = 0
    var MaxDownloadsPerClient: Int = 0
    var MaxConnectionsPerIP: Int = 0
    var IgnoreFiles: [String] = ["^\\.", "^@"]
    var EnableBonjour: Bool = false
}
