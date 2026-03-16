import Foundation
import SwiftUI

/// Central application state, injected into the SwiftUI environment.
@Observable
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

    /// Saves the current config to config.yaml.
    func saveConfig() {
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
        try mgr.save(config)
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

    func clearLogs() {
        logLines.removeAll()
    }

    // MARK: - Private

    private func appendLog(_ line: LogLine) {
        logLines.append(line)
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
    }

    private static var defaultConfigDir: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MobiusAdmin/config").path
    }
}
