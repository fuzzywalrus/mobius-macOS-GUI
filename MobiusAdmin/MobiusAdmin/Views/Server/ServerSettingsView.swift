import SwiftUI
import UniformTypeIdentifiers

/// Left panel: all Mobius server settings that generate config.yaml.
struct SettingsFormView: View {
    @Environment(AppState.self) private var appState
    @State private var newTracker = ""
    @State private var newIgnorePattern = ""
    @State private var showAgreementEditor = false
    @State private var showMessageBoardEditor = false

    var body: some View {
        @Bindable var state = appState

        ScrollView {
            Form {
                Section("Config Directory") {
                    HStack {
                        Text(appState.configDir)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Change...") {
                            pickDirectory()
                        }
                    }
                }

                Section("General") {
                    TextField("Server Name", text: binding(\.Name))
                    TextField("Description", text: binding(\.Description))
                    LabeledContent("Banner File") {
                        HStack {
                            Text(appState.config.BannerFile.isEmpty ? "None" : appState.config.BannerFile)
                                .foregroundStyle(appState.config.BannerFile.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Browse...") {
                                pickBanner()
                            }
                            if !appState.config.BannerFile.isEmpty {
                                Button(role: .destructive) {
                                    appState.config.BannerFile = ""
                                    appState.saveConfig()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    LabeledContent("File Root") {
                        HStack {
                            Text(appState.config.FileRoot.isEmpty ? "Not set" : appState.config.FileRoot)
                                .foregroundStyle(appState.config.FileRoot.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Browse...") {
                                pickFileRoot()
                            }
                        }
                    }

                    LabeledContent("Login Agreement") {
                        Button("Edit...") {
                            showAgreementEditor = true
                        }
                    }

                    LabeledContent("Message Board") {
                        Button("Edit...") {
                            showMessageBoardEditor = true
                        }
                    }
                }

                Section("Network") {
                    HStack {
                        Text("Hotline Port")
                        Spacer()
                        TextField("Port", value: Binding(
                            get: { appState.serverPort },
                            set: { appState.serverPort = $0 }
                        ), format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    }
                    Toggle("Enable Bonjour", isOn: binding(\.EnableBonjour))
                }

                Section("Tracker Registration") {
                    Toggle("Enable Tracker Registration", isOn: binding(\.EnableTrackerRegistration))

                    if appState.config.EnableTrackerRegistration {
                        ForEach(Array(appState.config.Trackers.enumerated()), id: \.offset) { index, tracker in
                            HStack {
                                Text(tracker)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button(role: .destructive) {
                                    appState.config.Trackers.remove(at: index)
                                    appState.saveConfig()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack {
                            TextField("host:port", text: $newTracker)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button("Add") {
                                let trimmed = newTracker.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                appState.config.Trackers.append(trimmed)
                                newTracker = ""
                                appState.saveConfig()
                            }
                            .disabled(newTracker.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                Section("Files") {
                    Toggle("Preserve Resource Forks", isOn: binding(\.PreserveResourceForks))

                    ForEach(Array(appState.config.IgnoreFiles.enumerated()), id: \.offset) { index, pattern in
                        HStack {
                            Text(pattern)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                appState.config.IgnoreFiles.remove(at: index)
                                appState.saveConfig()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        TextField("Regex pattern", text: $newIgnorePattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Add") {
                            let trimmed = newIgnorePattern.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            appState.config.IgnoreFiles.append(trimmed)
                            newIgnorePattern = ""
                            appState.saveConfig()
                        }
                        .disabled(newIgnorePattern.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("News") {
                    TextField("Date Format", text: binding(\.NewsDateFormat))
                    TextField("Delimiter", text: binding(\.NewsDelimiter))
                }

                Section("Limits") {
                    HStack {
                        Text("Max Downloads")
                        Spacer()
                        TextField("0 = unlimited", value: binding(\.MaxDownloads), format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Max Downloads Per Client")
                        Spacer()
                        TextField("0 = unlimited", value: binding(\.MaxDownloadsPerClient), format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Max Connections Per IP")
                        Spacer()
                        TextField("0 = unlimited", value: binding(\.MaxConnectionsPerIP), format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }

                if let error = appState.configError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $showAgreementEditor) {
            TextFileEditorView(
                title: "Login Agreement",
                filePath: (appState.configDir as NSString).appendingPathComponent("Agreement.txt")
            )
        }
        .sheet(isPresented: $showMessageBoardEditor) {
            TextFileEditorView(
                title: "Message Board",
                filePath: (appState.configDir as NSString).appendingPathComponent("MessageBoard.txt")
            )
        }
    }

    /// Creates a binding to a config property that auto-saves on change.
    private func binding<T>(_ keyPath: WritableKeyPath<ServerConfig, T>) -> Binding<T> where T: Equatable {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: { newValue in
                appState.config[keyPath: keyPath] = newValue
                appState.saveConfig()
            }
        )
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Mobius config directory"

        if panel.runModal() == .OK, let url = panel.url {
            appState.configDir = url.path
        }
    }

    private func pickFileRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Files directory"

        if panel.runModal() == .OK, let url = panel.url {
            appState.config.FileRoot = url.path
            appState.saveConfig()
        }
    }

    private func pickBanner() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.jpeg, .gif]
        panel.title = "Select banner image (JPG or GIF)"

        if panel.runModal() == .OK, let url = panel.url {
            // Copy the banner into the config directory so Mobius can find it
            let filename = url.lastPathComponent
            let dest = URL(fileURLWithPath: appState.configDir).appendingPathComponent(filename)
            let fm = FileManager.default
            do {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: url, to: dest)
                appState.config.BannerFile = filename
                appState.saveConfig()
            } catch {
                appState.configError = "Failed to copy banner: \(error.localizedDescription)"
            }
        }
    }
}

/// Modal editor for plain text files (Agreement.txt, MessageBoard.txt).
struct TextFileEditorView: View {
    let title: String
    let filePath: String

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(4)

            if let error {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { load() }
    }

    private func load() {
        do {
            text = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            text = ""
        }
    }

    private func save() {
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
            dismiss()
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}
