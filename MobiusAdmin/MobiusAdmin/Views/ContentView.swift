import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HSplitView {
            SettingsFormView()
                .frame(minWidth: 320, idealWidth: 380)

            RightPanelView()
                .frame(minWidth: 400, idealWidth: 520)
        }
    }
}

enum RightTab: String, CaseIterable, Identifiable {
    case server = "Server"
    case logs = "Logs"

    var id: String { rawValue }
}

struct RightPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: RightTab = .server

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(RightTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab == .server ? "server.rack" : "text.alignleft")
                            Text(tab.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Tab content
            switch selectedTab {
            case .server:
                ServerControlView()
            case .logs:
                LogView()
            }
        }
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
        case .running: return "Running"
        case .starting: return "Starting..."
        case .stopped: return "Stopped"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
