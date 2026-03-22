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

    var logLevel: String {
        get { UserDefaults.standard.string(forKey: "logLevel") ?? "info" }
        set { UserDefaults.standard.set(newValue, forKey: "logLevel") }
    }

    var logFilePath: String {
        get { UserDefaults.standard.string(forKey: "logFilePath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "logFilePath") }
    }

    var networkInterface: String {
        get { UserDefaults.standard.string(forKey: "networkInterface") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "networkInterface") }
    }

    var tlsCertPath: String {
        get { UserDefaults.standard.string(forKey: "tlsCertPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tlsCertPath") }
    }

    var tlsKeyPath: String {
        get { UserDefaults.standard.string(forKey: "tlsKeyPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tlsKeyPath") }
    }

    var tlsPort: Int {
        get {
            let port = UserDefaults.standard.integer(forKey: "tlsPort")
            return port > 0 ? port : 5600
        }
        set { UserDefaults.standard.set(newValue, forKey: "tlsPort") }
    }

    var tlsEnabled: Bool {
        !tlsCertPath.isEmpty && !tlsKeyPath.isEmpty
    }

    // MARK: - Config State

    var config = ServerConfig()
    var configError: String?

    // MARK: - Setup Wizard

    var showSetupWizard = false
    var showShutdownAlert = false
    var shutdownMessage = "Server is shutting down."

    var isFirstLaunch: Bool {
        let mgr = ConfigFileManager(configDir: URL(fileURLWithPath: configDir))
        return !mgr.configFileExists
    }

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

    private var launchConfig: ServerLaunchConfig {
        ServerLaunchConfig(
            configDir: URL(fileURLWithPath: configDir),
            serverPort: serverPort,
            logLevel: logLevel,
            logFilePath: logFilePath,
            networkInterface: networkInterface,
            tlsCertPath: tlsCertPath,
            tlsKeyPath: tlsKeyPath,
            tlsPort: tlsPort
        )
    }

    func startServer() {
        guard !configDir.isEmpty else { return }

        do {
            try ensureConfigDir()
        } catch {
            configError = "Failed to create config directory: \(error.localizedDescription)"
            return
        }

        // If no banner is configured, use the generic default banner
        if config.bannerFile.isEmpty {
            ensureDefaultBanner()
        }

        do {
            try processManager.start(config: launchConfig)
        } catch {
            // Error is captured in processManager.status
        }
    }

    func stopServer() {
        if apiClient != nil {
            showShutdownAlert = true
        } else {
            forceStop()
        }
    }

    func confirmShutdown() {
        let message = shutdownMessage
        showShutdownAlert = false
        shutdownMessage = "Server is shutting down."

        if let client = apiClient {
            Task {
                do {
                    try await client.shutdown(message: message)
                    try? await Task.sleep(for: .seconds(2))
                } catch {
                    // If API call fails, fall through to SIGTERM
                }
                processManager.stop()
                onlineUsers = []
                serverStats = nil
            }
        } else {
            forceStop()
        }
    }

    func forceStop() {
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

        if config.bannerFile.isEmpty {
            ensureDefaultBanner()
        }

        try? processManager.restart(config: launchConfig)
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

    /// Validates that a login name is safe for use as a filename.
    /// Only allows lowercase alphanumeric characters, underscores, and hyphens.
    static func isValidLogin(_ login: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-")
        return !login.isEmpty && login.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    func saveAccount(_ account: UserAccount) {
        accountError = nil

        guard Self.isValidLogin(account.login) else {
            accountError = "Invalid login name. Use only lowercase letters, numbers, hyphens, and underscores."
            return
        }

        let url = usersDir.appendingPathComponent("\(account.login).yaml")

        // Verify the resolved path stays inside the Users directory
        guard url.standardizedFileURL.path.hasPrefix(usersDir.standardizedFileURL.path) else {
            accountError = "Invalid login name."
            return
        }

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

        guard Self.isValidLogin(account.login) else {
            accountError = "Invalid login name."
            return
        }

        let url = usersDir.appendingPathComponent("\(account.login).yaml")

        guard url.standardizedFileURL.path.hasPrefix(usersDir.standardizedFileURL.path) else {
            accountError = "Invalid login name."
            return
        }

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

    // MARK: - Setup Wizard Commit

    func commitWizardDraft(_ draft: WizardDraft, startServer: Bool) {
        // Validate required fields
        if draft.serverDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            configError = "A server description is required."
            return
        }

        // Map draft values to config
        config.name = draft.serverName
        config.description = draft.serverDescription
        config.fileRoot = draft.fileRoot
        config.enableBonjour = draft.enableBonjour
        config.enableTrackerRegistration = draft.enableTrackerRegistration
        config.trackers = draft.enabledTrackers
        config.newsDateFormat = draft.newsDateFormat
        config.newsDelimiter = draft.newsDelimiter
        config.maxDownloads = draft.maxDownloads
        config.maxDownloadsPerClient = draft.maxDownloadsPerClient
        config.maxConnectionsPerIP = draft.maxConnectionsPerIP
        serverPort = draft.serverPort

        // Ensure directory structure and save config
        do {
            try ensureConfigDir()
        } catch {
            configError = "Failed to create config directory: \(error.localizedDescription)"
            return
        }

        // Write Agreement.txt
        let agreementPath = URL(fileURLWithPath: configDir).appendingPathComponent("Agreement.txt")
        try? draft.agreementText.write(to: agreementPath, atomically: true, encoding: .utf8)

        // Copy banner
        if draft.useDefaultBanner {
            // Copy default banner from app bundle
            if let bundleBanner = Bundle.main.url(forResource: "default-banner", withExtension: "jpg") {
                let dest = URL(fileURLWithPath: configDir).appendingPathComponent("banner.jpg")
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: bundleBanner, to: dest)
                    config.bannerFile = "banner.jpg"
                } catch {
                    configError = "Failed to copy default banner: \(error.localizedDescription)"
                }
            }
        } else if let bannerURL = draft.bannerSourceURL {
            let dest = URL(fileURLWithPath: configDir).appendingPathComponent(draft.bannerFilename)
            let fm = FileManager.default
            do {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: bannerURL, to: dest)
                config.bannerFile = draft.bannerFilename
            } catch {
                configError = "Failed to copy banner: \(error.localizedDescription)"
            }
        }

        // Save final config
        saveConfigNow()

        if startServer {
            self.startServer()
        }
    }

    // MARK: - Default Banner

    /// Copies the bundled default-banner.jpg into the config directory as banner.jpg
    /// and updates config.bannerFile so the Go binary has a valid file to load.
    func ensureDefaultBanner() {
        guard let bundleBanner = Bundle.main.url(forResource: "default-banner", withExtension: "jpg") else { return }
        let dest = URL(fileURLWithPath: configDir).appendingPathComponent("banner.jpg")
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: bundleBanner, to: dest)
            config.bannerFile = "banner.jpg"
            saveConfigNow()
        } catch {
            configError = "Failed to copy default banner: \(error.localizedDescription)"
        }
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
