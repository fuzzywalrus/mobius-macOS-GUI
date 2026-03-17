import SwiftUI
import Yams

/// News tab: view and manage the threaded news categories and the flat message board.
struct NewsView: View {
    @Environment(AppState.self) private var appState
    @State private var section: NewsSection = .messageBoard
    @State private var threadedNews: ThreadedNewsData = .init()
    @State private var newsError: String?

    enum NewsSection: String, CaseIterable {
        case messageBoard = "Message Board"
        case threadedNews = "Threaded News"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                ForEach(NewsSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch section {
            case .messageBoard:
                MessageBoardEditorView()
            case .threadedNews:
                ThreadedNewsView(news: $threadedNews, error: $newsError)
                    .onAppear { loadThreadedNews() }
            }
        }
    }

    private func loadThreadedNews() {
        let path = (appState.configDir as NSString).appendingPathComponent("ThreadedNews.yaml")
        guard FileManager.default.fileExists(atPath: path) else {
            threadedNews = ThreadedNewsData()
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            threadedNews = try YAMLDecoder().decode(ThreadedNewsData.self, from: data)
        } catch {
            newsError = "Failed to load: \(error.localizedDescription)"
        }
    }
}

// MARK: - Message Board Editor (inline, not a sheet)

struct MessageBoardEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var error: String?
    @State private var isDirty = false

    private var filePath: String {
        (appState.configDir as NSString).appendingPathComponent("MessageBoard.txt")
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(4)
                .onChange(of: text) { isDirty = true }

            if let error {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            Divider()

            HStack {
                Spacer()
                if isDirty {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Save") { save() }
                    .disabled(!isDirty)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(8)
        }
        .onAppear { load() }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: filePath) else {
            text = ""
            return
        }
        do {
            text = try String(contentsOfFile: filePath, encoding: .utf8)
            isDirty = false
        } catch {
            self.error = "Failed to load: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try text.write(toFile: filePath, atomically: true, encoding: .utf8)
            isDirty = false
            error = nil
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Threaded News

struct ThreadedNewsData: Codable {
    var categories: [String: NewsCategory] = [:]

    enum CodingKeys: String, CodingKey {
        case categories = "Categories"
    }
}

struct NewsCategory: Codable, Identifiable {
    var name: String
    var type: String  // "category" or "bundle"
    var articles: [String: NewsArticle]?
    var subCats: [String: NewsCategory]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case type = "Type"
        case articles = "Articles"
        case subCats = "SubCats"
    }
}

struct NewsArticle: Codable, Identifiable {
    var title: String
    var poster: String
    var date: String
    var body: String
    var parentArt: Int?

    var id: String { "\(poster):\(title):\(date)" }

    enum CodingKeys: String, CodingKey {
        case title = "Title"
        case poster = "Poster"
        case date = "Date"
        case body = "Body"
        case parentArt = "ParentArt"
    }
}

struct ThreadedNewsView: View {
    @Environment(AppState.self) private var appState
    @Binding var news: ThreadedNewsData
    @Binding var error: String?
    @State private var selectedCategory: String?
    @State private var newCategoryName = ""

    var body: some View {
        HSplitView {
            // Categories sidebar
            VStack(spacing: 0) {
                if news.categories.isEmpty {
                    VStack {
                        Spacer()
                        Text("No categories")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                    }
                } else {
                    List(sortedCategories, id: \.key, selection: $selectedCategory) { key, cat in
                        HStack {
                            Image(systemName: cat.type == "bundle" ? "newspaper" : "folder")
                                .foregroundStyle(.secondary)
                            Text(cat.name)
                        }
                        .tag(key)
                    }
                    .listStyle(.sidebar)
                }

                Divider()

                HStack {
                    TextField("Category name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button(action: addCategory) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(6)
            }
            .frame(minWidth: 160, idealWidth: 180)

            // Category detail
            if let key = selectedCategory, let cat = news.categories[key] {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(cat.name)
                            .font(.headline)
                        Spacer()
                        Button("Delete Category", role: .destructive) {
                            news.categories.removeValue(forKey: key)
                            selectedCategory = nil
                            saveNews()
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if let articles = cat.articles, !articles.isEmpty {
                        List(articles.sorted(by: { $0.key < $1.key }), id: \.key) { _, article in
                            VStack(alignment: .leading) {
                                Text(article.title)
                                    .font(.body.bold())
                                HStack {
                                    Text("by \(article.poster)")
                                    Text(article.date)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if !article.body.isEmpty {
                                    Text(article.body)
                                        .font(.caption)
                                        .lineLimit(3)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listStyle(.inset)
                    } else {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("No articles")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a category")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var sortedCategories: [(key: String, value: NewsCategory)] {
        news.categories.sorted { $0.key < $1.key }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let key = name
        news.categories[key] = NewsCategory(name: name, type: "bundle")
        newCategoryName = ""
        saveNews()
    }

    private func saveNews() {
        let path = (appState.configDir as NSString).appendingPathComponent("ThreadedNews.yaml")
        do {
            let yaml = try YAMLEncoder().encode(news)
            try yaml.write(toFile: path, atomically: true, encoding: .utf8)
            error = nil
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}
