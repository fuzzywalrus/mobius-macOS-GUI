import SwiftUI

struct ServerControlView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                // Status
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 14, height: 14)
                    Text(statusText)
                        .font(.title2)
                }

                if appState.serverStatus.isRunning {
                    Text("Hotline port \(appState.serverPort) \u{2022} API port \(appState.processManager.apiPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Controls
                HStack(spacing: 12) {
                    Button(action: { appState.startServer() }) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .disabled(appState.serverStatus.isRunning || !appState.hasBinary)

                    Button(action: { appState.stopServer() }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .disabled(!appState.serverStatus.isRunning)

                    Button(action: { appState.restartServer() }) {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                    .disabled(!appState.serverStatus.isRunning || !appState.hasBinary)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !appState.hasBinary {
                    Label(
                        "Server binary not found in app bundle. Rebuild with: make gui",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var statusColor: Color {
        switch appState.serverStatus {
        case .running: return .green
        case .starting: return .yellow
        case .stopped: return .gray
        case .error: return .red
        }
    }

    private var statusText: String {
        switch appState.serverStatus {
        case .running: return "Server is running"
        case .starting: return "Server is starting..."
        case .stopped: return "Server is stopped"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
