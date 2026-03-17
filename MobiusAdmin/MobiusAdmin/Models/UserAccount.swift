import Foundation
import Yams

/// Mirrors the Mobius user account YAML structure (e.g. Users/admin.yaml).
struct UserAccount: Codable, Identifiable {
    var login: String
    var name: String
    var password: String
    var access: AccessPermissions
    var fileRoot: String

    var id: String { login }

    enum CodingKeys: String, CodingKey {
        case login = "Login"
        case name = "Name"
        case password = "Password"
        case access = "Access"
        case fileRoot = "FileRoot"
    }

    /// Create a new account with sensible guest-like defaults.
    static func newAccount(login: String) -> UserAccount {
        UserAccount(
            login: login,
            name: login,
            password: "",
            access: .guest,
            fileRoot: ""
        )
    }
}

/// All 35 Hotline access permission flags, matching the Mobius YAML keys exactly.
struct AccessPermissions: Codable, Equatable {
    var downloadFile: Bool = false
    var downloadFolder: Bool = false
    var uploadFile: Bool = false
    var uploadFolder: Bool = false
    var deleteFile: Bool = false
    var renameFile: Bool = false
    var moveFile: Bool = false
    var createFolder: Bool = false
    var deleteFolder: Bool = false
    var renameFolder: Bool = false
    var moveFolder: Bool = false
    var readChat: Bool = false
    var sendChat: Bool = false
    var openChat: Bool = false
    var closeChat: Bool = false
    var showInList: Bool = false
    var createUser: Bool = false
    var deleteUser: Bool = false
    var openUser: Bool = false
    var modifyUser: Bool = false
    var changeOwnPass: Bool = false
    var newsReadArt: Bool = false
    var newsPostArt: Bool = false
    var disconnectUser: Bool = false
    var cannotBeDisconnected: Bool = false
    var getClientInfo: Bool = false
    var uploadAnywhere: Bool = false
    var anyName: Bool = false
    var noAgreement: Bool = false
    var setFileComment: Bool = false
    var setFolderComment: Bool = false
    var viewDropBoxes: Bool = false
    var makeAlias: Bool = false
    var broadcast: Bool = false
    var newsDeleteArt: Bool = false
    var newsCreateCat: Bool = false
    var newsDeleteCat: Bool = false
    var newsCreateFldr: Bool = false
    var newsDeleteFldr: Bool = false
    var sendPrivMsg: Bool = false

    enum CodingKeys: String, CodingKey {
        case downloadFile = "DownloadFile"
        case downloadFolder = "DownloadFolder"
        case uploadFile = "UploadFile"
        case uploadFolder = "UploadFolder"
        case deleteFile = "DeleteFile"
        case renameFile = "RenameFile"
        case moveFile = "MoveFile"
        case createFolder = "CreateFolder"
        case deleteFolder = "DeleteFolder"
        case renameFolder = "RenameFolder"
        case moveFolder = "MoveFolder"
        case readChat = "ReadChat"
        case sendChat = "SendChat"
        case openChat = "OpenChat"
        case closeChat = "CloseChat"
        case showInList = "ShowInList"
        case createUser = "CreateUser"
        case deleteUser = "DeleteUser"
        case openUser = "OpenUser"
        case modifyUser = "ModifyUser"
        case changeOwnPass = "ChangeOwnPass"
        case newsReadArt = "NewsReadArt"
        case newsPostArt = "NewsPostArt"
        case disconnectUser = "DisconnectUser"
        case cannotBeDisconnected = "CannotBeDisconnected"
        case getClientInfo = "GetClientInfo"
        case uploadAnywhere = "UploadAnywhere"
        case anyName = "AnyName"
        case noAgreement = "NoAgreement"
        case setFileComment = "SetFileComment"
        case setFolderComment = "SetFolderComment"
        case viewDropBoxes = "ViewDropBoxes"
        case makeAlias = "MakeAlias"
        case broadcast = "Broadcast"
        case newsDeleteArt = "NewsDeleteArt"
        case newsCreateCat = "NewsCreateCat"
        case newsDeleteCat = "NewsDeleteCat"
        case newsCreateFldr = "NewsCreateFldr"
        case newsDeleteFldr = "NewsDeleteFldr"
        case sendPrivMsg = "SendPrivMsg"
    }

    /// Default guest permissions.
    static let guest = AccessPermissions(
        downloadFile: true, downloadFolder: true,
        readChat: true, sendChat: true, openChat: true,
        showInList: true,
        newsReadArt: true, newsPostArt: true,
        getClientInfo: true,
        sendPrivMsg: true
    )

    /// Full admin permissions.
    static let admin: AccessPermissions = {
        var p = AccessPermissions()
        p.downloadFile = true; p.downloadFolder = true
        p.uploadFile = true; p.uploadFolder = true
        p.deleteFile = true; p.renameFile = true; p.moveFile = true
        p.createFolder = true; p.deleteFolder = true
        p.renameFolder = true; p.moveFolder = true
        p.readChat = true; p.sendChat = true; p.openChat = true
        p.closeChat = true; p.showInList = true
        p.createUser = true; p.deleteUser = true
        p.openUser = true; p.modifyUser = true; p.changeOwnPass = true
        p.newsReadArt = true; p.newsPostArt = true
        p.disconnectUser = true; p.cannotBeDisconnected = true
        p.getClientInfo = true; p.uploadAnywhere = true
        p.anyName = true; p.noAgreement = true
        p.setFileComment = true; p.setFolderComment = true
        p.viewDropBoxes = true; p.makeAlias = true
        p.newsDeleteArt = true; p.newsCreateCat = true
        p.newsDeleteCat = true; p.newsCreateFldr = true
        p.newsDeleteFldr = true; p.sendPrivMsg = true
        return p
    }()

    /// Groups of permissions for display in the UI.
    struct PermissionGroup: Identifiable {
        let name: String
        let permissions: [(label: String, keyPath: WritableKeyPath<AccessPermissions, Bool>)]
        var id: String { name }
    }

    static let groups: [PermissionGroup] = [
        PermissionGroup(name: "Files", permissions: [
            ("Download Files", \AccessPermissions.downloadFile),
            ("Download Folders", \AccessPermissions.downloadFolder),
            ("Upload Files", \AccessPermissions.uploadFile),
            ("Upload Folders", \AccessPermissions.uploadFolder),
            ("Upload Anywhere", \AccessPermissions.uploadAnywhere),
            ("Delete Files", \AccessPermissions.deleteFile),
            ("Delete Folders", \AccessPermissions.deleteFolder),
            ("Rename Files", \AccessPermissions.renameFile),
            ("Rename Folders", \AccessPermissions.renameFolder),
            ("Move Files", \AccessPermissions.moveFile),
            ("Move Folders", \AccessPermissions.moveFolder),
            ("Create Folders", \AccessPermissions.createFolder),
            ("Set File Comments", \AccessPermissions.setFileComment),
            ("Set Folder Comments", \AccessPermissions.setFolderComment),
            ("View Drop Boxes", \AccessPermissions.viewDropBoxes),
            ("Make Aliases", \AccessPermissions.makeAlias),
        ]),
        PermissionGroup(name: "Chat", permissions: [
            ("Read Chat", \AccessPermissions.readChat),
            ("Send Chat", \AccessPermissions.sendChat),
            ("Open Private Chat", \AccessPermissions.openChat),
            ("Close Chat", \AccessPermissions.closeChat),
        ]),
        PermissionGroup(name: "Users", permissions: [
            ("Create Accounts", \AccessPermissions.createUser),
            ("Delete Accounts", \AccessPermissions.deleteUser),
            ("Read Accounts", \AccessPermissions.openUser),
            ("Modify Accounts", \AccessPermissions.modifyUser),
            ("Change Own Password", \AccessPermissions.changeOwnPass),
            ("Disconnect Users", \AccessPermissions.disconnectUser),
            ("Cannot Be Disconnected", \AccessPermissions.cannotBeDisconnected),
            ("Get Client Info", \AccessPermissions.getClientInfo),
            ("Show In List", \AccessPermissions.showInList),
        ]),
        PermissionGroup(name: "News", permissions: [
            ("Read Articles", \AccessPermissions.newsReadArt),
            ("Post Articles", \AccessPermissions.newsPostArt),
            ("Delete Articles", \AccessPermissions.newsDeleteArt),
            ("Create Categories", \AccessPermissions.newsCreateCat),
            ("Delete Categories", \AccessPermissions.newsDeleteCat),
            ("Create News Bundles", \AccessPermissions.newsCreateFldr),
            ("Delete News Bundles", \AccessPermissions.newsDeleteFldr),
        ]),
        PermissionGroup(name: "Messaging", permissions: [
            ("Send Private Messages", \AccessPermissions.sendPrivMsg),
            ("Broadcast", \AccessPermissions.broadcast),
        ]),
        PermissionGroup(name: "Miscellaneous", permissions: [
            ("Use Any Name", \AccessPermissions.anyName),
            ("Don't Show Agreement", \AccessPermissions.noAgreement),
        ]),
    ]
}
