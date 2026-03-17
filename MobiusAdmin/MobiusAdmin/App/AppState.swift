import Foundation
import SwiftUI
import Yams

/// Central application state, injected into the SwiftUI environment.
@Observable
@MainActor
final class AppState {
    let processManager = ProcessManager()

    // MARK: - Settings (persisted via UserDefaults)

    var configDir: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "configDir"), !saved.isEmpty {
                return saved
            }
            return Self.defaultConfigDir
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "configDir")
            loadConfigIfExists()
        }
    }

    var serverPort: Int {
        get {
            let port = UserDefaults.standard.integer(forKey: "serverPort")
            return port > 0 ? port : 5500
        }
        set { UserDefaults.standard.set(newValue, forKey: "serverPort") }
    }

    // MARK: - Config State

    var config = ServerConfig()
    var configError: String?

    // MARK: - Log State

    var logLines: [LogLine] = []
    private let maxLogLines = 10_000

    // MARK: - Account Management

    var accounts: [UserAccount] = []
    var accountError: String?

    // MARK: - Online Users

    var onlineUsers: [OnlineUser] = []
    var serverStats: ServerStats?
    var bannedIPs: [String] = []
    var bannedUsernames: [String] = []
    var bannedNicknames: [String] = []

    // MARK: - API Client

    var apiClient: APIClient? {
        guard processManager.status.isRunning, processManager.apiPort > 0 else { return nil }
        return APIClient(port: processManager.apiPort, apiKey: processManager.apiKey)
    }

    // MARK: - Save Debouncing

    private var saveTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        processManager.onLogLine = { [weak self] line in
            self?.appendLog(line)
        }
        loadConfigIfExists()
    }

    // MARK: - Config Management

    /// Loads config.yaml from configDir if it exists, otherwise keeps current defaults.
    func loadConfigIfExists() {
        configError = nil
        guard !configDir.isEmpty else { return }

        let mgr = ConfigFileManager(configDir: URL(fileURLWithPath: configDir))
        guard mgr.configFileExists else { return }

        do {
            config = try mgr.load()
        } catch {
            configError = "Failed to load config: \(error.localizedDescription)"
        }
    }

    /// Saves the current config to config.yaml after a short debounce.
    func saveConfig() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveConfigNow()
        }
    }

    /// Saves the current config to config.yaml immediately.
    func saveConfigNow() {
        guard !configDir.isEmpty else { return }
        let mgr = ConfigFileManager(configDir: URL(fileURLWithPath: configDir))

        do {
            try mgr.save(config)
            configError = nil
        } catch {
            configError = "Failed to save config: \(error.localizedDescription)"
        }
    }

    /// Ensures the config directory has the full structure Mobius expects.
    func ensureConfigDir() throws {
        guard !configDir.isEmpty else { return }
        let mgr = ConfigFileManager(configDir: URL(fileURLWithPath: configDir))
        try mgr.ensureDirectoryStructure()
        saveConfigNow()
    }

    // MARK: - Server Control

    var serverStatus: ProcessManager.ServerStatus {
        processManager.status
    }

    var hasBinary: Bool {
        ProcessManager.embeddedBinaryURL != nil
    }

    func startServer() {
        guard !configDir.isEmpty else { return }

        do {
            try ensureConfigDir()
        } catch {
            configError = "Failed to create config directory: \(error.localizedDescription)"
            return
        }

        let configURL = URL(fileURLWithPath: configDir)
        do {
            try processManager.start(configDir: configURL, serverPort: serverPort)
        } catch {
            // Error is captured in processManager.status
        }
    }

    func stopServer() {
        processManager.stop()
        onlineUsers = []
        serverStats = nil
    }

    func restartServer() {
        guard !configDir.isEmpty else { return }

        do {
            try ensureConfigDir()
        } catch {
            configError = "Failed to create config directory: \(error.localizedDescription)"
            return
        }

        let configURL = URL(fileURLWithPath: configDir)
        try? processManager.restart(configDir: configURL, serverPort: serverPort)
    }

    /// Ask the running server to reload its configuration from disk.
    func reloadServerConfig() {
        guard let client = apiClient else { return }
        Task {
            do {
                try await client.reloadConfig()
            } catch {
                configError = "Reload failed: \(error.localizedDescription)"
            }
        }
    }

    func clearLogs() {
        logLines.removeAll()
    }

    // MARK: - Account Management

    var usersDir: URL {
        URL(fileURLWithPath: configDir).appendingPathComponent("Users")
    }

    func loadAccounts() {
        accountError = nil
        let fm = FileManager.default
        let dir = usersDir

        guard fm.fileExists(atPath: dir.path) else {
            accounts = []
            return
        }

        do {
            let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "yaml" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            let decoder = YAMLDecoder()
            accounts = files.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(UserAccount.self, from: data)
            }
        } catch {
            accountError = "Failed to load accounts: \(error.localizedDescription)"
        }
    }

    func saveAccount(_ account: UserAccount) {
        accountError = nil
        let url = usersDir.appendingPathComponent("\(account.login).yaml")

        do {
            let encoder = YAMLEncoder()
            let yaml = try encoder.encode(account)
            try yaml.write(to: url, atomically: true, encoding: .utf8)
            loadAccounts()
        } catch {
            accountError = "Failed to save account: \(error.localizedDescription)"
        }
    }

    func deleteAccount(_ account: UserAccount) {
        accountError = nil
        let url = usersDir.appendingPathComponent("\(account.login).yaml")

        do {
            try FileManager.default.removeItem(at: url)
            loadAccounts()
        } catch {
            accountError = "Failed to delete account: \(error.localizedDescription)"
        }
    }

    // MARK: - Online Users & Bans

    func refreshOnlineUsers() {
        guard let client = apiClient else { return }
        Task {
            do {
                onlineUsers = try await client.fetchOnlineUsers()
            } catch {
                // Silently fail — server may be briefly unavailable
            }
        }
    }

    func refreshStats() {
        guard let client = apiClient else { return }
        Task {
            do {
                serverStats = try await client.fetchStats()
            } catch {
                // Silently fail
            }
        }
    }

    func refreshBans() {
        guard let client = apiClient else { return }
        Task {
            do {
                bannedIPs = try await client.fetchBannedIPs()
                bannedUsernames = try await client.fetchBannedUsernames()
                bannedNicknames = try await client.fetchBannedNicknames()
            } catch {
                // Silently fail
            }
        }
    }

    func banIP(_ ip: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.ban(ip: ip)
            refreshBans()
        }
    }

    func unbanIP(_ ip: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.unban(ip: ip)
            refreshBans()
        }
    }

    func banUsername(_ username: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.ban(username: username)
            refreshBans()
        }
    }

    func unbanUsername(_ username: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.unban(username: username)
            refreshBans()
        }
    }

    func banNickname(_ nickname: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.ban(nickname: nickname)
            refreshBans()
        }
    }

    func unbanNickname(_ nickname: String) {
        guard let client = apiClient else { return }
        Task {
            try? await client.unban(nickname: nickname)
            refreshBans()
        }
    }

    // MARK: - File Root

    /// Resolves the file root path. If relative, resolves against configDir.
    var resolvedFileRoot: String {
        let root = config.fileRoot
        if root.isEmpty { return "" }
        if root.hasPrefix("/") { return root }
        return URL(fileURLWithPath: configDir).appendingPathComponent(root).path
    }

    // MARK: - Private

    private func appendLog(_ line: LogLine) {
        logLines.append(line)
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
    }

    private static var defaultConfigDir: String {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return NSTemporaryDirectory() + "MobiusAdmin/config"
        }
        return appSupport.appendingPathComponent("MobiusAdmin/config").path
    }
}
