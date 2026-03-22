import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var updateChecker = UpdateChecker()

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("MobiusAdmin")
                .font(.title.bold())

            Text("Version \(updateChecker.currentVersion)")
                .font(.body)
                .foregroundStyle(.secondary)

            if let serverVersion = ProcessManager.serverVersion {
                Text("Mobius Server \(serverVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("A native macOS GUI for the Mobius Hotline server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(maxWidth: 280)

            // Update status
            Group {
                if updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else if updateChecker.updateAvailable, let version = updateChecker.latestVersion {
                    VStack(spacing: 6) {
                        Label("Version \(version) is available!", systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.callout)
                        if let url = updateChecker.releaseURL {
                            Link("Download Update", destination: url)
                                .font(.callout)
                        }
                    }
                } else if updateChecker.latestVersion != nil {
                    Label("You're up to date.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                } else if let error = updateChecker.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Button("Check for Updates") {
                updateChecker.checkForUpdates()
            }
            .disabled(updateChecker.isChecking)

            Divider()
                .frame(maxWidth: 280)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/fuzzywalrus/mobius-macOS-GUI")!) {
                    Label("MobiusAdmin on GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/jhalter/mobius")!) {
                    Label("Mobius Hotline Server by Jeff Halter", systemImage: "link")
                }

                Link(destination: URL(string: "https://greggant.com")!) {
                    Label("greggant.com", systemImage: "person")
                }
            }
            .font(.callout)

            Spacer()
                .frame(height: 8)
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            updateChecker.checkForUpdates()
        }
    }
}
