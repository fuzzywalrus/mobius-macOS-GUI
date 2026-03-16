import Foundation

/// A single line of log output from the server process.
struct LogLine: Identifiable {
    enum Source {
        case stdout
        case stderr
    }

    let id = UUID()
    let timestamp: Date
    let source: Source
    let text: String
}
