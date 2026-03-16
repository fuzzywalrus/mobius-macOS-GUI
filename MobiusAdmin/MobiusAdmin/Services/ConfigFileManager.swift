import Foundation
import Yams

/// Reads, writes, and scaffolds the Mobius config directory.
struct ConfigFileManager {
    let configDir: URL

    var configFileURL: URL {
        configDir.appendingPathComponent("config.yaml")
    }

    var configFileExists: Bool {
        FileManager.default.fileExists(atPath: configFileURL.path)
    }

    func load() throws -> ServerConfig {
        let data = try Data(contentsOf: configFileURL)
        let decoder = YAMLDecoder()
        return try decoder.decode(ServerConfig.self, from: data)
    }

    func save(_ config: ServerConfig) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir.path) {
            try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(config)
        try yamlString.write(to: configFileURL, atomically: true, encoding: .utf8)
    }

    /// Creates the full config directory structure needed by Mobius.
    func ensureDirectoryStructure() throws {
        let fm = FileManager.default

        // Create main config dir
        if !fm.fileExists(atPath: configDir.path) {
            try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        // Create Files/ subdirectory
        let filesDir = configDir.appendingPathComponent("Files")
        if !fm.fileExists(atPath: filesDir.path) {
            try fm.createDirectory(at: filesDir, withIntermediateDirectories: true)
        }

        // Create Users/ subdirectory with defaults
        let usersDir = configDir.appendingPathComponent("Users")
        if !fm.fileExists(atPath: usersDir.path) {
            try fm.createDirectory(at: usersDir, withIntermediateDirectories: true)
        }

        let adminPath = usersDir.appendingPathComponent("admin.yaml")
        if !fm.fileExists(atPath: adminPath.path) {
            try Self.defaultAdminAccount.write(to: adminPath, atomically: true, encoding: .utf8)
        }

        let guestPath = usersDir.appendingPathComponent("guest.yaml")
        if !fm.fileExists(atPath: guestPath.path) {
            try Self.defaultGuestAccount.write(to: guestPath, atomically: true, encoding: .utf8)
        }

        // Create Agreement.txt
        let agreementPath = configDir.appendingPathComponent("Agreement.txt")
        if !fm.fileExists(atPath: agreementPath.path) {
            try "Welcome to this Hotline server.".write(to: agreementPath, atomically: true, encoding: .utf8)
        }

        // Create MessageBoard.txt
        let messageBoardPath = configDir.appendingPathComponent("MessageBoard.txt")
        if !fm.fileExists(atPath: messageBoardPath.path) {
            try "".write(to: messageBoardPath, atomically: true, encoding: .utf8)
        }

        // Create ThreadedNews.yaml
        let threadedNewsPath = configDir.appendingPathComponent("ThreadedNews.yaml")
        if !fm.fileExists(atPath: threadedNewsPath.path) {
            try Self.defaultThreadedNews.write(to: threadedNewsPath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Default user account YAML

    private static let defaultAdminAccount = """
    Login: admin
    Name: admin
    Password: $2a$04$2itGEYx8C1N5bsfRSoC9JuonS3I4YfnyVPZHLSwp7kEInRX0yoB.a
    Access:
        DownloadFile: true
        DownloadFolder: true
        UploadFile: true
        UploadFolder: true
        DeleteFile: true
        RenameFile: true
        MoveFile: true
        CreateFolder: true
        DeleteFolder: true
        RenameFolder: true
        MoveFolder: true
        ReadChat: true
        SendChat: true
        OpenChat: true
        CloseChat: true
        ShowInList: true
        CreateUser: true
        DeleteUser: true
        OpenUser: true
        ModifyUser: true
        ChangeOwnPass: true
        NewsReadArt: true
        NewsPostArt: true
        DisconnectUser: true
        CannotBeDisconnected: true
        GetClientInfo: true
        UploadAnywhere: true
        AnyName: true
        NoAgreement: true
        SetFileComment: true
        SetFolderComment: true
        ViewDropBoxes: true
        MakeAlias: true
        Broadcast: false
        NewsDeleteArt: true
        NewsCreateCat: true
        NewsDeleteCat: true
        NewsCreateFldr: true
        NewsDeleteFldr: true
        SendPrivMsg: true
    FileRoot: ""
    """

    private static let defaultGuestAccount = """
    Login: guest
    Name: guest
    Password: ""
    Access:
        DownloadFile: true
        DownloadFolder: true
        UploadFile: false
        UploadFolder: false
        DeleteFile: false
        RenameFile: false
        MoveFile: false
        CreateFolder: false
        DeleteFolder: false
        RenameFolder: false
        MoveFolder: false
        ReadChat: true
        SendChat: true
        OpenChat: true
        CloseChat: false
        ShowInList: true
        CreateUser: false
        DeleteUser: false
        OpenUser: false
        ModifyUser: false
        ChangeOwnPass: false
        NewsReadArt: true
        NewsPostArt: true
        DisconnectUser: false
        CannotBeDisconnected: false
        GetClientInfo: true
        UploadAnywhere: false
        AnyName: false
        NoAgreement: false
        SetFileComment: false
        SetFolderComment: false
        ViewDropBoxes: false
        MakeAlias: false
        Broadcast: false
        NewsDeleteArt: false
        NewsCreateCat: false
        NewsDeleteCat: false
        NewsCreateFldr: false
        NewsDeleteFldr: false
        SendPrivMsg: true
    FileRoot: ""
    """

    private static let defaultThreadedNews = "Categories: {}\n"
}
