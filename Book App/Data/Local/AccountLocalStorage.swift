import Foundation
import CryptoKit

@MainActor
final class AccountLocalStorage {
    static let legacyFileNames = [
        "library.json", "reading-sessions.json", "book-content.json",
        "reading-goals.json", "custom-book-lists.json", "reading-reminders.json"
    ]
    static let accountFileNames = legacyFileNames + ["reading-check-ins.json", "reader-profile.json", "review-moods.json"]
    private let root: URL
    private let fileManager: FileManager

    init(root: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.root = try root ?? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("BookApp", isDirectory: true)
    }

    func directory(for userID: String) -> URL {
        let key = SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(key, isDirectory: true)
    }

    func needsLegacyChoice(for userID: String) -> Bool {
        !fileManager.fileExists(atPath: directory(for: userID).path) &&
        Self.legacyFileNames.contains { fileManager.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    /// Copies to a staging directory and renames only after every file validates.
    /// Original installation data is never moved, rewritten, or deleted.
    func prepare(userID: String, importLegacy: Bool) throws -> AccountStorageScope {
        let destination = directory(for: userID)
        if fileManager.fileExists(atPath: destination.path) {
            // The sync journal repairs interrupted projection writes before stores load.
            if !fileManager.fileExists(atPath: destination.appendingPathComponent("sync-journal-v1.json").path) {
                try validate(directory: destination)
            }
            return AccountStorageScope(directory: destination)
        }
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".staging-" + UUID().uuidString)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            if importLegacy {
                for name in Self.legacyFileNames {
                    let source = root.appendingPathComponent(name)
                    if fileManager.fileExists(atPath: source.path) {
                        try fileManager.copyItem(at: source, to: staging.appendingPathComponent(name))
                    }
                }
            }
            try validate(directory: staging)
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            // Only disposable staging data may be removed.
            try? fileManager.removeItem(at: staging)
            throw error
        }
        return AccountStorageScope(directory: destination)
    }

    private func validate(directory: URL) throws {
        let scope = AccountStorageScope(directory: directory)
        _ = try LocalLibraryDataSource(scope: scope).loadBooks()
        _ = try LocalReadingSessionDataSource(scope: scope).loadSessions()
        _ = try LocalBookContentDataSource(scope: scope).loadContent()
        _ = try LocalJSONRepository<[ReadingGoal]>(fileName: "reading-goals.json", directory: directory).load(default: [])
        _ = try LocalJSONRepository<[CustomBookList]>(fileName: "custom-book-lists.json", directory: directory).load(default: [])
        let reminder = try LocalJSONRepository<ReadingReminderPreferences>(
            fileName: "reading-reminders.json", directory: directory
        ).load(default: ReadingReminderPreferences())
        guard reminder.isValid else { throw CocoaError(.coderReadCorrupt) }
    }
}
