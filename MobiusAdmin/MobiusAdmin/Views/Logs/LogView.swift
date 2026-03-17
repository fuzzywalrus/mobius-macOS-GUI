import SwiftUI

struct LogView: View {
    @Environment(AppState.self) private var appState
    @State private var filterText = ""
    @State private var autoScroll = true
    @State private var showStderr = true
    @State private var showStdout = true
    @State private var filteredLines: [LogLine] = []

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Filter logs...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Toggle("stdout", isOn: $showStdout)
                    .toggleStyle(.checkbox)
                Toggle("stderr", isOn: $showStderr)
                    .toggleStyle(.checkbox)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button("Clear") {
                    appState.clearLogs()
                }
            }
            .padding(8)

            Divider()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredLines) { line in
                            LogLineView(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: filteredLines.count) {
                    if autoScroll, let last = filteredLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle("Logs")
        .onChange(of: appState.logLines.count) { updateFilteredLines() }
        .onChange(of: filterText) { updateFilteredLines() }
        .onChange(of: showStdout) { updateFilteredLines() }
        .onChange(of: showStderr) { updateFilteredLines() }
        .onAppear { updateFilteredLines() }
    }

    private func updateFilteredLines() {
        filteredLines = appState.logLines.filter { line in
            let sourceMatch: Bool
            switch line.source {
            case .stdout: sourceMatch = showStdout
            case .stderr: sourceMatch = showStderr
            }

            guard sourceMatch else { return false }

            if filterText.isEmpty { return true }
            return line.text.localizedCaseInsensitiveContains(filterText)
        }
    }
}

struct LogLineView: View {
    let line: LogLine

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: line.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(line.source == .stderr ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
    }
}
