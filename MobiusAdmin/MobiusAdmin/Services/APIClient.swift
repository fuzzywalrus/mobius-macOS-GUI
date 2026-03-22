import Foundation

/// HTTP client for the Mobius server REST API.
/// Communicates with the running server via the randomly assigned API port and key.
actor APIClient {
    enum APIError: LocalizedError {
        case httpError(statusCode: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .httpError(let statusCode, let body):
                return "HTTP \(statusCode): \(body)"
            }
        }
    }

    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession

    init(port: Int, apiKey: String) {
        self.baseURL = URL(string: "http://127.0.0.1:\(port)")!
        self.apiKey = apiKey
        self.session = URLSession(configuration: .ephemeral)
    }

    // MARK: - Online Users

    func fetchOnlineUsers() async throws -> [OnlineUser] {
        let data = try await get("/api/v1/online")
        // The API may return null when no users are connected.
        if let users = try? JSONDecoder().decode([OnlineUser].self, from: data) {
            return users
        }
        return []
    }

    // MARK: - Stats

    func fetchStats() async throws -> ServerStats {
        let data = try await get("/api/v1/stats")
        return try JSONDecoder().decode(ServerStats.self, from: data)
    }

    // MARK: - Ban Management

    func ban(username: String? = nil, nickname: String? = nil, ip: String? = nil) async throws {
        var body: [String: String] = [:]
        if let username { body["username"] = username }
        if let nickname { body["nickname"] = nickname }
        if let ip { body["ip"] = ip }
        _ = try await post("/api/v1/ban", body: body)
    }

    func unban(username: String? = nil, nickname: String? = nil, ip: String? = nil) async throws {
        var body: [String: String] = [:]
        if let username { body["username"] = username }
        if let nickname { body["nickname"] = nickname }
        if let ip { body["ip"] = ip }
        _ = try await post("/api/v1/unban", body: body)
    }

    func fetchBannedIPs() async throws -> [String] {
        let data = try await get("/api/v1/banned/ips")
        if let ips = try? JSONDecoder().decode([String].self, from: data) {
            return ips
        }
        return []
    }

    func fetchBannedUsernames() async throws -> [String] {
        let data = try await get("/api/v1/banned/usernames")
        if let names = try? JSONDecoder().decode([String].self, from: data) {
            return names
        }
        return []
    }

    func fetchBannedNicknames() async throws -> [String] {
        let data = try await get("/api/v1/banned/nicknames")
        if let nicks = try? JSONDecoder().decode([String].self, from: data) {
            return nicks
        }
        return []
    }

    // MARK: - Server Control

    func reloadConfig() async throws {
        _ = try await post("/api/v1/reload", body: nil as [String: String]?)
    }

    func shutdown(message: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/shutdown"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(message.utf8)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // MARK: - Private

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func post<T: Encodable>(_ path: String, body: T?) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}
