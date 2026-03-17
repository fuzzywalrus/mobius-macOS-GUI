import Foundation

/// A currently connected user, as returned by the Mobius REST API.
struct OnlineUser: Codable, Identifiable {
    let login: String
    let nickname: String
    let ip: String

    var id: String { "\(login):\(ip)" }
}

/// Server statistics from the /api/v1/stats endpoint.
struct ServerStats: Codable {
    let currentlyConnected: Int
    let downloadsInProgress: Int
    let uploadsInProgress: Int
    let waitingDownloads: Int
    let connectionPeak: Int
    let connectionCounter: Int
    let downloadCounter: Int
    let uploadCounter: Int
    let since: String

    enum CodingKeys: String, CodingKey {
        case currentlyConnected = "CurrentlyConnected"
        case downloadsInProgress = "DownloadsInProgress"
        case uploadsInProgress = "UploadsInProgress"
        case waitingDownloads = "WaitingDownloads"
        case connectionPeak = "ConnectionPeak"
        case connectionCounter = "ConnectionCounter"
        case downloadCounter = "DownloadCounter"
        case uploadCounter = "UploadCounter"
        case since = "Since"
    }
}
