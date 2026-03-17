import SwiftUI

/// Online tab: split view with connected users on top, logs on bottom.
struct OnlineView: View {
    @Environment(AppState.self) private var appState
    @State private var refreshTimer: Timer?
    @State private var selectedUserID: OnlineUser.ID?

    var body: some View {
        VSplitView {
            // Top half: online users
            onlineUsersSection
                .frame(minHeight: 120, idealHeight: 200)

            // Bottom half: logs
            LogView()
                .frame(minHeight: 150, idealHeight: 250)
        }
        .onAppear { startRefresh() }
        .onDisappear { stopRefresh() }
    }

    @ViewBuilder
    private var onlineUsersSection: some View {
        if !appState.serverStatus.isRunning {
            VStack {
                Spacer()
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Server is not running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 0) {
                // Users table
                Table(appState.onlineUsers, selection: $selectedUserID) {
                    TableColumn("Login", value: \.login)
                        .width(min: 80, ideal: 120)
                    TableColumn("Nickname", value: \.nickname)
                        .width(min: 80, ideal: 120)
                    TableColumn("IP Address", value: \.ip)
                        .width(min: 100, ideal: 140)
                    TableColumn("") { user in
                        Button(role: .destructive) {
                            appState.banIP(user.ip)
                        } label: {
                            Image(systemName: "hand.raised")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Ban IP \(user.ip)")
                    }
                    .width(30)
                }

                if appState.onlineUsers.isEmpty {
                    Spacer()
                    Text("No users connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private func startRefresh() {
        appState.refreshOnlineUsers()
        appState.refreshStats()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                appState.refreshOnlineUsers()
                appState.refreshStats()
            }
        }
    }

    private func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
