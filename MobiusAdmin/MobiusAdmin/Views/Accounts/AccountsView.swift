import SwiftUI

/// Accounts tab: user account YAML management + ban management.
struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedLogin: String?
    @State private var showNewAccountSheet = false
    @State private var showDeleteConfirm = false
    @State private var accountToDelete: UserAccount?
    @State private var section: AccountSection = .users

    enum AccountSection: String, CaseIterable {
        case users = "Users"
        case bans = "Bans"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section picker
            Picker("", selection: $section) {
                ForEach(AccountSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch section {
            case .users:
                usersSection
            case .bans:
                BanManagementView()
            }
        }
        .onAppear { appState.loadAccounts() }
    }

    private var usersSection: some View {
        HSplitView {
            // Account list sidebar
            VStack(spacing: 0) {
                List(appState.accounts, selection: $selectedLogin) { account in
                    HStack {
                        Image(systemName: isAdmin(account) ? "person.badge.key" : "person")
                            .foregroundStyle(isAdmin(account) ? .orange : .secondary)
                        VStack(alignment: .leading) {
                            Text(account.login)
                                .font(.body)
                            Text(account.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(account.login)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            accountToDelete = account
                            showDeleteConfirm = true
                        }
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button(action: { showNewAccountSheet = true }) {
                        Image(systemName: "plus")
                    }
                    Button(action: {
                        if let login = selectedLogin, let account = appState.accounts.first(where: { $0.login == login }) {
                            accountToDelete = account
                            showDeleteConfirm = true
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedLogin == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(minWidth: 160, idealWidth: 180)

            // Account detail
            if let login = selectedLogin, let account = appState.accounts.first(where: { $0.login == login }) {
                AccountDetailView(account: account)
            } else {
                VStack {
                    Spacer()
                    Text("Select an account")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showNewAccountSheet) {
            NewAccountSheet { newAccount in
                appState.saveAccount(newAccount)
                selectedLogin = newAccount.login
            }
        }
        .alert("Delete Account", isPresented: $showDeleteConfirm, presenting: accountToDelete) { account in
            Button("Delete", role: .destructive) {
                if selectedLogin == account.login { selectedLogin = nil }
                appState.deleteAccount(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Delete the account \"\(account.login)\"? This cannot be undone.")
        }
    }

    private func isAdmin(_ account: UserAccount) -> Bool {
        account.access.createUser && account.access.deleteUser && account.access.modifyUser
    }
}

// MARK: - Account Detail

struct AccountDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var draft: UserAccount
    @State private var changePassword = false

    let account: UserAccount

    init(account: UserAccount) {
        self.account = account
        self._draft = State(initialValue: account)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Basic info
                GroupBox("Account Info") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Login") {
                            Text(draft.login)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Display Name") {
                            TextField("Name", text: $draft.name)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }
                        LabeledContent("File Root") {
                            TextField("Default", text: $draft.fileRoot, prompt: Text("Use server default"))
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }

                        Divider()

                        Toggle("Reset Password", isOn: $changePassword)
                        if changePassword {
                            Text("This will clear the password so the account has no password. To set a specific password, use a Hotline client — Mobius requires bcrypt hashing which is not supported in this GUI.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                }

                // Permissions
                ForEach(AccessPermissions.groups) { group in
                    GroupBox(group.name) {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading),
                        ], spacing: 6) {
                            ForEach(group.permissions, id: \.label) { perm in
                                Toggle(perm.label, isOn: Binding(
                                    get: { draft.access[keyPath: perm.keyPath] },
                                    set: { draft.access[keyPath: perm.keyPath] = $0 }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.caption)
                            }
                        }
                        .padding(4)
                    }
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Apply Template: Guest") {
                        draft.access = .guest
                    }
                    Button("Apply Template: Admin") {
                        draft.access = .admin
                    }
                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("Revert") {
                        draft = account
                        changePassword = false
                    }
                    .disabled(draft == account && !changePassword)

                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .onChange(of: account.login) {
            draft = account
            changePassword = false
        }
    }

    private func save() {
        var toSave = draft
        if changePassword {
            // Reset to the known bcrypt hash for an empty password.
            // Setting specific passwords requires a Hotline client (bcrypt hashing).
            toSave.password = "$2y$10$jINeSWW2yhkwf.O6Eznq6O2yfV.SGtj3rzx1cmEqB1LIlt3OG1nOq"
        }
        appState.saveAccount(toSave)
        changePassword = false
    }
}

extension UserAccount: Equatable {
    static func == (lhs: UserAccount, rhs: UserAccount) -> Bool {
        lhs.login == rhs.login && lhs.name == rhs.name &&
        lhs.password == rhs.password && lhs.access == rhs.access &&
        lhs.fileRoot == rhs.fileRoot
    }
}

// MARK: - New Account Sheet

struct NewAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var login = ""
    var onSave: (UserAccount) -> Void

    private var sanitizedLogin: String {
        login.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isValid: Bool {
        AppState.isValidLogin(sanitizedLogin)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("New Account")
                .font(.headline)

            TextField("Login name", text: $login)
                .textFieldStyle(.roundedBorder)

            if !login.trimmingCharacters(in: .whitespaces).isEmpty && !isValid {
                Text("Only lowercase letters, numbers, hyphens, and underscores are allowed.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    guard isValid else { return }
                    onSave(UserAccount.newAccount(login: sanitizedLogin))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Ban Management

struct BanManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var newBanIP = ""
    @State private var newBanUsername = ""
    @State private var newBanNickname = ""

    var body: some View {
        if !appState.serverStatus.isRunning {
            VStack {
                Spacer()
                Image(systemName: "network.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Server must be running to manage bans")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    banSection(title: "Banned IPs", items: appState.bannedIPs,
                               newValue: $newBanIP, placeholder: "192.168.1.100",
                               onAdd: { appState.banIP($0) },
                               onRemove: { appState.unbanIP($0) })

                    banSection(title: "Banned Usernames", items: appState.bannedUsernames,
                               newValue: $newBanUsername, placeholder: "username",
                               onAdd: { appState.banUsername($0) },
                               onRemove: { appState.unbanUsername($0) })

                    banSection(title: "Banned Nicknames", items: appState.bannedNicknames,
                               newValue: $newBanNickname, placeholder: "nickname",
                               onAdd: { appState.banNickname($0) },
                               onRemove: { appState.unbanNickname($0) })
                }
                .padding()
            }
            .onAppear { appState.refreshBans() }
        }
    }

    private func banSection(title: String, items: [String], newValue: Binding<String>,
                            placeholder: String, onAdd: @escaping (String) -> Void,
                            onRemove: @escaping (String) -> Void) -> some View {
        GroupBox(title) {
            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(8)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                onRemove(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            HStack {
                TextField(placeholder, text: newValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Ban") {
                    let trimmed = newValue.wrappedValue.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed)
                    newValue.wrappedValue = ""
                }
                .disabled(newValue.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
