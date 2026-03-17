import SwiftUI
import UniformTypeIdentifiers

// MARK: - Step 1: Welcome

struct WizardWelcomeStep: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Welcome to MobiusAdmin")
                .font(.largeTitle.bold())

            Text("Let's set up your Hotline server. This wizard will walk you through the essential settings. You can always change these later in the settings panel.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Spacer()
        }
    }
}

// MARK: - Step 2: Server Name

struct WizardServerNameStep: View {
    @Binding var name: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("What is your Server Name?")
                .font(.title.bold())

            Text("This name is displayed to users when they connect and appears in tracker listings so people can find your server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            TextField("My Hotline Server", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .frame(maxWidth: 360)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}

// MARK: - Step 3: Description

struct WizardDescriptionStep: View {
    @Binding var description: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Describe your Server")
                .font(.title.bold())

            Text("A short description shown in tracker listings so visitors know what your server is about.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            TextField("A Hotline server for sharing files and chatting", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .lineLimit(3...5)
                .frame(maxWidth: 420)

            if description.trimmingCharacters(in: .whitespaces).isEmpty {
                Label("A description is required by the server.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }
}

// MARK: - Step 4: File Root

struct WizardFileRootStep: View {
    @Binding var fileRoot: String
    let configDir: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Where are your Shared Files?")
                .font(.title.bold())

            Text("This is the folder that connected users can browse and download from. By default, your ~/Public folder is used.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack {
                Text(displayPath)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button("Browse...") { pickDirectory() }
            }
            .padding()
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .frame(maxWidth: 420)

            Button("Use Default (Files)") {
                fileRoot = "Files"
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var displayPath: String {
        if fileRoot.isEmpty {
            return (configDir as NSString).appendingPathComponent("Files")
        }
        return fileRoot
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Files Directory"

        if panel.runModal() == .OK, let url = panel.url {
            fileRoot = url.path
        }
    }
}

// MARK: - Step 5: Banner

struct WizardBannerStep: View {
    @Binding var useDefault: Bool
    @Binding var sourceURL: URL?
    @Binding var filename: String
    @State private var previewImage: NSImage?
    @State private var sizeWarning: String?
    @State private var dimensionWarning: String?

    private var displayImage: NSImage? {
        if useDefault {
            if let url = Bundle.main.url(forResource: "default-banner", withExtension: "jpg") {
                return NSImage(contentsOf: url)
            }
            return nil
        }
        return previewImage
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Set a Server Banner")
                .font(.title.bold())

            Text("An optional banner image shown to users when they connect. The standard size is **468 x 60 pixels**, in JPG or GIF format, and must be under 256 KB.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if let image = displayImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 468, maxHeight: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }

            if useDefault {
                Text("Using default MobiusAdmin banner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Choose Custom Image...") {
                    pickBanner()
                }

                if !useDefault && sourceURL != nil {
                    Button("Use Default") {
                        useDefault = true
                        sourceURL = nil
                        filename = ""
                        previewImage = nil
                        sizeWarning = nil
                        dimensionWarning = nil
                    }
                    .font(.caption)
                }

            }

            if let warning = dimensionWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let warning = sizeWarning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
    }

    private func pickBanner() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.jpeg, .gif]
        panel.title = "Select Banner Image (JPG or GIF)"

        if panel.runModal() == .OK, let url = panel.url {
            useDefault = false
            sourceURL = url
            filename = url.lastPathComponent

            if let image = NSImage(contentsOf: url) {
                previewImage = image

                // Check pixel dimensions via the image rep
                if let rep = image.representations.first {
                    let w = rep.pixelsWide
                    let h = rep.pixelsHigh
                    if w != 468 || h != 60 {
                        dimensionWarning = "Image is \(w) x \(h) — should be 468 x 60 pixels."
                    } else {
                        dimensionWarning = nil
                    }
                }
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64, size > 262_140 {
                sizeWarning = "File is \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) — exceeds the 256 KB limit."
            } else {
                sizeWarning = nil
            }
        }
    }
}

// MARK: - Step 6: Agreement

struct WizardAgreementStep: View {
    @Binding var text: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Login Agreement")
                .font(.title.bold())

            Text("This message is shown to users when they first connect to your server. You can use it for rules, welcome messages, or server info.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                .frame(maxWidth: 460, maxHeight: 200)
        }
    }
}

// MARK: - Step 7: Network

struct WizardNetworkStep: View {
    @Binding var port: Int
    @Binding var enableBonjour: Bool

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Network Settings")
                .font(.title.bold())

            Text("The standard Hotline port is **5500** (file transfers use the next port, 5501). If you want people outside your local network to connect, you'll need to forward ports **5500** and **5501** on your router to this computer. Enable Bonjour to advertise your server to others on your local network.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 12) {
                HStack {
                    Text("Hotline Port")
                        .frame(width: 120, alignment: .trailing)
                    TextField("5500", value: Binding(
                        get: { port },
                        set: { port = max(1, min(65535, $0)) }
                    ), format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("Bonjour")
                        .frame(width: 120, alignment: .trailing)
                    Toggle("Advertise on local network", isOn: $enableBonjour)
                }
            }
            .frame(maxWidth: 360)

            Spacer()
        }
    }
}

// MARK: - Step 8: Trackers

struct WizardTrackerStep: View {
    @Binding var enabled: Bool
    @Binding var options: [TrackerOption]
    @State private var customTracker = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Tracker Registration")
                .font(.title.bold())

            Text("Trackers are public directories where people discover Hotline servers. Enable registration to make your server visible to the community.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Toggle("Register with Hotline Trackers", isOn: $enabled)
                .toggleStyle(.switch)

            if enabled {
                VStack(spacing: 8) {
                    ForEach($options) { $option in
                        Toggle(option.address, isOn: $option.enabled)
                            .toggleStyle(.checkbox)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
                .frame(maxWidth: 380)

                HStack {
                    TextField("custom.tracker:5499", text: $customTracker)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 240)
                    Button("Add") {
                        let trimmed = customTracker.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        options.append(TrackerOption(address: trimmed, enabled: true))
                        customTracker = ""
                    }
                    .disabled(customTracker.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Step 9: News

struct WizardNewsStep: View {
    @Binding var dateFormat: String
    @Binding var delimiter: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("News Settings")
                .font(.title.bold())

            Text("Configure how dates appear on the message board. The delimiter is the separator line placed between each post.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 12) {
                Picker("Date Format", selection: $dateFormat) {
                    Text("Jan02 15:04 (default)").tag("Jan02 15:04")
                    Text("01/02/2006 3:04 PM (US)").tag("01/02/2006 3:04 PM")
                    Text("02/01/2006 15:04 (Europe)").tag("02/01/2006 15:04")
                    Text("2006-01-02 15:04 (ISO)").tag("2006-01-02 15:04")
                    Text("Mon Jan 2 15:04:05 (Full)").tag("Mon Jan 2 15:04:05")
                }
                .frame(maxWidth: 360)

                LabeledContent("Post Separator") {
                    TextField("__________________________________________________________", text: $delimiter)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                .frame(maxWidth: 360)
            }

            Spacer()
        }
    }
}

// MARK: - Step 10: Limits

struct WizardLimitsStep: View {
    @Binding var maxDownloads: Int
    @Binding var maxDownloadsPerClient: Int
    @Binding var maxConnectionsPerIP: Int

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Connection Limits")
                .font(.title.bold())

            Text("Set limits on downloads and connections to manage server resources. Set any value to 0 for unlimited.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 12) {
                limitRow("Max Downloads", value: $maxDownloads)
                limitRow("Max Downloads Per Client", value: $maxDownloadsPerClient)
                limitRow("Max Connections Per IP", value: $maxConnectionsPerIP)
            }
            .frame(maxWidth: 360)

            Text("Set to 0 for unlimited")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func limitRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
        }
    }
}

// MARK: - Step 11: Accounts

struct WizardAccountsStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Default Accounts")
                .font(.title.bold())

            Text("Two accounts are created automatically when your server is set up.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 12) {
                accountCard(
                    icon: "person.badge.key",
                    iconColor: .orange,
                    login: "admin",
                    description: "Full access to all server features. Default password is \"admin\"."
                )

                accountCard(
                    icon: "person",
                    iconColor: .blue,
                    login: "guest",
                    description: "Can download files, chat, and read news. No password required."
                )
            }
            .frame(maxWidth: 400)

            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Change the admin password after your first login using a Hotline client.", systemImage: "exclamationmark.shield")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("You can also manage accounts from the Accounts tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            }
            .frame(maxWidth: 400)

            Spacer()
        }
    }

    private func accountCard(icon: String, iconColor: Color, login: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(login)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - Step 12: Done

struct WizardDoneStep: View {
    let draft: WizardDraft

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title.bold())

            Text("Here's a summary of your configuration. You can change any of these later in the settings panel.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            // Summary
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                summaryRow("Server Name", draft.serverName)
                if !draft.serverDescription.isEmpty {
                    summaryRow("Description", draft.serverDescription)
                }
                summaryRow("File Root", draft.fileRoot)
                summaryRow("Port", "\(draft.serverPort)")
                if draft.useDefaultBanner {
                    summaryRow("Banner", "Default")
                } else if !draft.bannerFilename.isEmpty {
                    summaryRow("Banner", draft.bannerFilename)
                }
                if draft.enableTrackerRegistration {
                    summaryRow("Trackers", "\(draft.enabledTrackers.count) registered")
                }
                summaryRow("Bonjour", draft.enableBonjour ? "Enabled" : "Disabled")
            }
            .font(.caption)
            .padding()
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .frame(maxWidth: 400)

            Spacer()
        }
    }

    @ViewBuilder
    private func summaryRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .fontWeight(.medium)
                .gridColumnAlignment(.leading)
        }
    }
}
