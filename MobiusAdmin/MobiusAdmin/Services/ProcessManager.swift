import Foundation

/// Bundles all CLI arguments for launching the server binary.
struct ServerLaunchConfig {
    let configDir: URL
    let serverPort: Int
    let logLevel: String
    let logFilePath: String
    let networkInterface: String
    let tlsCertPath: String
    let tlsKeyPath: String
    let tlsPort: Int
}

/// Manages the lifecycle of the mobius-hotline-server binary as a child process.
@Observable
@MainActor
final class ProcessManager {
    enum ServerStatus: Equatable {
        case stopped
        case starting
        case running
        case error(String)

        var isRunning: Bool {
            if case .running = self { return true }
            if case .starting = self { return true }
            return false
        }

        var statusColor: String {
            switch self {
            case .running: return "green"
            case .starting: return "yellow"
            case .stopped: return "gray"
            case .error: return "red"
            }
        }

        var label: String {
            switch self {
            case .running: return "Running"
            case .starting: return "Starting..."
            case .stopped: return "Stopped"
            case .error(let msg): return "Error: \(msg)"
            }
        }

        var detailedLabel: String {
            switch self {
            case .running: return "Server is running"
            case .starting: return "Server is starting..."
            case .stopped: return "Server is stopped"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    private(set) var status: ServerStatus = .stopped
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    /// The randomly assigned API port for this session.
    private(set) var apiPort: Int = 0
    /// The randomly generated API key for this session.
    private(set) var apiKey: String = ""

    var onLogLine: ((LogLine) -> Void)?

    /// Returns the URL of the embedded server binary inside the app bundle.
    static var embeddedBinaryURL: URL? {
        Bundle.main.url(forResource: "mobius-hotline-server", withExtension: nil)
    }

    /// Start the server binary with the given configuration.
    func start(config: ServerLaunchConfig) throws {
        guard process == nil else { return }

        guard let binaryURL = Self.embeddedBinaryURL else {
            status = .error("Server binary not found in app bundle")
            return
        }

        // Validate port range before converting to UInt16
        guard (1...65535).contains(config.serverPort) else {
            status = .error("Port must be between 1 and 65535.")
            return
        }

        // Check if the port is already in use before attempting to start
        if Self.isPortInUse(port: UInt16(config.serverPort)) {
            status = .error("Port \(config.serverPort) is already in use. Stop any existing server first.")
            return
        }

        status = .starting

        // Pick a random API port and generate a key, ensuring it's not in use
        apiPort = Self.findFreePort(in: 15500...15599)
        apiKey = UUID().uuidString

        let proc = Process()
        proc.executableURL = binaryURL
        proc.qualityOfService = .userInitiated
        // Ensure child process belongs to our process group so it is
        // killed automatically if the parent process is terminated.
        var args = [
            "--config", config.configDir.path,
            "--api-addr", "127.0.0.1:\(apiPort)",
            "--api-key", apiKey,
            "--bind", "\(config.serverPort)",
            "--log-level", config.logLevel,
        ]
        if !config.logFilePath.isEmpty {
            args += ["--log-file", config.logFilePath]
        }
        if !config.networkInterface.isEmpty {
            args += ["--interface", config.networkInterface]
        }
        if !config.tlsCertPath.isEmpty && !config.tlsKeyPath.isEmpty {
            args += ["--tls-cert", config.tlsCertPath, "--tls-key", config.tlsKeyPath, "--tls-port", "\(config.tlsPort)"]
        }
        proc.arguments = args

        // Set up pipes for log capture
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr
        stdoutPipe = stdout
        stderrPipe = stderr

        // Handle unexpected termination
        proc.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                // Ignore if stop() already cleaned up
                guard self.process != nil else { return }

                let status = process.terminationStatus
                if status == 0 {
                    self.status = .stopped
                } else if process.terminationReason == .uncaughtSignal && (status == SIGTERM || status == SIGINT) {
                    self.status = .stopped
                } else {
                    self.status = .error("Server exited with code \(status)")
                }
                self.cleanupProcess()
            }
        }

        do {
            try proc.run()
            process = proc
            status = .running

            // Start reading output asynchronously
            readPipe(stdout, source: .stdout)
            readPipe(stderr, source: .stderr)
        } catch {
            status = .error(error.localizedDescription)
            cleanupProcess()
            throw error
        }
    }

    /// Stop the server by sending SIGTERM and waiting for exit.
    func stop() {
        guard let process else {
            status = .stopped
            return
        }

        // Prevent terminationHandler from interfering
        process.terminationHandler = nil

        if process.isRunning {
            process.terminate()

            // Wait up to 5 seconds for graceful exit
            let deadline = Date().addingTimeInterval(5.0)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }

            // Force kill if still running
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
        }

        cleanupProcess()
        status = .stopped
    }

    /// Restart the server with the same configuration.
    func restart(config: ServerLaunchConfig) throws {
        stop()
        try start(config: config)
    }

    private func cleanupProcess() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
    }

    private func readPipe(_ pipe: Pipe, source: LogLine.Source) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in lines {
                    let logLine = LogLine(timestamp: Date(), source: source, text: line)
                    DispatchQueue.main.async {
                        self?.onLogLine?(logLine)
                    }
                }
            }
        }
    }

    /// Find a free port in the given range, falling back to the first port if all appear in use.
    private static func findFreePort(in range: ClosedRange<Int>) -> Int {
        for port in range.shuffled() {
            if !isPortInUse(port: UInt16(port)) {
                return port
            }
        }
        return range.lowerBound
    }

    /// Check if a TCP port is already in use by attempting to bind to it.
    private static func isPortInUse(port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result != 0
    }
}
