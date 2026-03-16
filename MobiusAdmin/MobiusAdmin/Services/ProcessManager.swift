import Foundation

/// Manages the lifecycle of the mobius-hotline-server binary as a child process.
@Observable
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
    func start(configDir: URL, serverPort: Int) throws {
        guard process == nil else { return }

        guard let binaryURL = Self.embeddedBinaryURL else {
            status = .error("Server binary not found in app bundle")
            return
        }

        // Check if the port is already in use before attempting to start
        if isPortInUse(port: UInt16(serverPort)) {
            status = .error("Port \(serverPort) is already in use. Stop any existing server first.")
            return
        }

        status = .starting

        // Pick a random API port and generate a key
        apiPort = Int.random(in: 15500...15599)
        apiKey = UUID().uuidString

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = [
            "--config", configDir.path,
            "--api-addr", "127.0.0.1:\(apiPort)",
            "--api-key", apiKey,
            "--bind", "\(serverPort)",
            "--log-level", "info",
        ]

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
                if process.terminationStatus == 0 || process.terminationReason == .uncaughtSignal {
                    self.status = .stopped
                } else {
                    self.status = .error("Server exited with code \(process.terminationStatus)")
                }
                self.process = nil
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
            process = nil
            throw error
        }
    }

    /// Stop the server by sending SIGTERM.
    func stop() {
        guard let process else {
            status = .stopped
            self.process = nil
            return
        }

        if process.isRunning {
            process.terminate()
            // Wait briefly for graceful shutdown
            process.waitUntilExit()
        }

        status = .stopped
        self.process = nil
    }

    /// Restart the server with the same configuration.
    func restart(configDir: URL, serverPort: Int) throws {
        stop()
        try start(configDir: configDir, serverPort: serverPort)
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

    /// Check if a TCP port is already in use by attempting to bind to it.
    private func isPortInUse(port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result != 0
    }
}
