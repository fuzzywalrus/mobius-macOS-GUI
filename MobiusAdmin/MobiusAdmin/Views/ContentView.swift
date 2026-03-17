import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        HSplitView {
            SettingsFormView()
                .frame(minWidth: 320, idealWidth: 380)

            RightPanelView()
                .frame(minWidth: 400, idealWidth: 520)
        }
        .sheet(isPresented: $state.showSetupWizard) {
            SetupWizardView()
                .environment(appState)
        }
        .onAppear {
            if appState.isFirstLaunch {
                appState.showSetupWizard = true
            }
        }
    }
}

enum RightTab: String, CaseIterable, Identifiable {
    case server = "Server"
    case accounts = "Accounts"
    case online = "Online"
    case files = "Files"
    case news = "News"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .server: return "server.rack"
        case .accounts: return "person.2"
        case .online: return "rectangle.split.1x2"
        case .files: return "folder"
        case .news: return "newspaper"
        }
    }
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
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                Spacer()

                // Server controls
                HStack(spacing: 4) {
                    Button(action: { appState.startServer() }) {
                        Image(systemName: "play.fill")
                    }
                    .disabled(appState.serverStatus.isRunning)
                    .help("Start Server")

                    Button(action: { appState.stopServer() }) {
                        Image(systemName: "stop.fill")
                    }
                    .disabled(!appState.serverStatus.isRunning)
                    .help("Stop Server")

                    Button(action: { appState.restartServer() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!appState.hasBinary)
                    .help("Restart Server")

                    Button(action: { appState.reloadServerConfig() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!appState.serverStatus.isRunning)
                    .help("Reload Config")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Tab content
            switch selectedTab {
            case .server:
                ServerControlView()
            case .accounts:
                AccountsView()
            case .online:
                OnlineView()
            case .files:
                FileBrowserView()
            case .news:
                NewsView()
            }

            Divider()

            // Persistent footer: stats (left) + server status (right)
            HStack(spacing: 6) {
                if appState.serverStatus.isRunning, let stats = appState.serverStats {
                    statBadge("Connected", value: stats.currentlyConnected, icon: "person.2")
                    statBadge("Peak", value: stats.connectionPeak, icon: "chart.bar")
                    statBadge("DL", value: stats.downloadsInProgress, icon: "arrow.down.circle")
                    statBadge("UL", value: stats.uploadsInProgress, icon: "arrow.up.circle")
                }

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.serverStatus.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if appState.serverStatus.isRunning {
                    Text("port \(appState.serverPort)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func statBadge(_ label: String, value: Int, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(value)")
                .font(.system(.caption, design: .monospaced).bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
}
