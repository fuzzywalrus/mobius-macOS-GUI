import SwiftUI

/// Files tab: browse the server's file root directory.
struct FileBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPath: String = ""
    @State private var items: [FileItem] = []
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb bar
            HStack {
                Button(action: { navigateTo(appState.resolvedFileRoot) }) {
                    Image(systemName: "house")
                }
                .buttonStyle(.borderless)
                .disabled(currentPath == appState.resolvedFileRoot)

                if !currentPath.isEmpty {
                    Button(action: navigateUp) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentPath == appState.resolvedFileRoot)
                }

                Text(displayPath)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { loadDirectory(currentPath) }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if appState.resolvedFileRoot.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No file root configured")
                        .foregroundStyle(.secondary)
                    Text("Set a File Root in the settings panel")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if let error {
                VStack {
                    Spacer()
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(items) { item in
                    HStack {
                        Image(systemName: item.isDirectory ? "folder.fill" : fileIcon(for: item.name))
                            .foregroundStyle(item.isDirectory ? .blue : .secondary)
                            .frame(width: 20)

                        Text(item.name)
                            .lineLimit(1)

                        Spacer()

                        if !item.isDirectory, let size = item.size {
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let date = item.modDate {
                            Text(date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if item.isDirectory {
                            navigateTo(item.path)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            let root = appState.resolvedFileRoot
            if !root.isEmpty {
                navigateTo(root)
            }
        }
        .onChange(of: appState.resolvedFileRoot) {
            let root = appState.resolvedFileRoot
            if !root.isEmpty {
                navigateTo(root)
            }
        }
    }

    private var displayPath: String {
        let root = appState.resolvedFileRoot
        guard !root.isEmpty, currentPath.hasPrefix(root) else { return currentPath }
        let relative = String(currentPath.dropFirst(root.count))
        return relative.isEmpty ? "/" : relative
    }

    private func navigateTo(_ path: String) {
        currentPath = path
        loadDirectory(path)
    }

    private func navigateUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        let root = appState.resolvedFileRoot
        if parent.hasPrefix(root) {
            navigateTo(parent)
        }
    }

    private func loadDirectory(_ path: String) {
        error = nil
        let fm = FileManager.default

        guard fm.fileExists(atPath: path) else {
            error = "Directory not found"
            items = []
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(atPath: path)
                .filter { !$0.hasPrefix(".") }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            items = contents.compactMap { name in
                let fullPath = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { return nil }

                let attrs = try? fm.attributesOfItem(atPath: fullPath)
                let size = attrs?[.size] as? Int64
                let modDate = attrs?[.modificationDate] as? Date

                return FileItem(
                    name: name,
                    path: fullPath,
                    isDirectory: isDir.boolValue,
                    size: isDir.boolValue ? nil : size,
                    modDate: modDate
                )
            }
        } catch {
            self.error = error.localizedDescription
            items = []
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        case "mp3", "wav", "aiff", "flac", "m4a":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "zip", "sit", "hqx", "gz", "tar", "dmg":
            return "archivebox"
        case "txt", "rtf", "md":
            return "doc.text"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }
}

struct FileItem: Identifiable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modDate: Date?

    var id: String { path }
}
