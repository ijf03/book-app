import Foundation
import Testing
@testable import Book_App

@MainActor struct ReaderProfileTests {
    @Test func welcomeEndsAfterSaveAndDoesNotOverwriteArrivingProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root)
        let welcome = ReaderProfileStore(scope: scope)
        #expect(welcome.needsWelcome)
        let existing = ReaderProfile.draft(username: "existing_reader", preferredName: "Existing", bio: "")
        let incoming = ReaderProfileStore(scope: scope)
        #expect(incoming.save(existing))
        let staleDraft = ReaderProfile.draft(username: "new_reader", preferredName: "", bio: "")
        #expect(welcome.save(staleDraft, onlyIfMissing: true))
        #expect(welcome.profile == existing && !welcome.needsWelcome)
        #expect(!ReaderProfileStore(scope: scope).needsWelcome)
        scope.invalidate()
        welcome.clear()
        #expect(!welcome.needsWelcome)
    }

    @Test func legacyPromptOnlyAppliesToUnpreparedAccountsWithOldFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try AccountLocalStorage(root: root)
        #expect(!storage.needsLegacyChoice(for: "A"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = Data("[]".utf8)
        try original.write(to: root.appendingPathComponent("library.json"))
        #expect(storage.needsLegacyChoice(for: "A"))
        _ = try storage.prepare(userID: "A", importLegacy: false)
        #expect(!storage.needsLegacyChoice(for: "A"))
        #expect(storage.needsLegacyChoice(for: "B"))
        #expect(try Data(contentsOf: root.appendingPathComponent("library.json")) == original)
    }

    @Test func profileValidationAndOptionalNames() {
        let value = ReaderProfile.draft(username: " Reader_01 ", preferredName: " Sabi ", bio: " Books! ")
        #expect(value.username == "reader_01" && value.displayName == "Sabi")
        #expect(value.validationError == nil)
        #expect(ReaderProfile.draft(username: "reader", preferredName: " ", bio: "").displayName == "reader")
        #expect(ReaderProfile.draft(username: "a b", preferredName: "", bio: "").validationError != nil)
        #expect(ReaderProfile.draft(username: "reader", preferredName: String(repeating: "x", count: 61), bio: "").validationError != nil)
    }

    @Test func profileSurvivesRestartAndRemoteProjectionButNotAccountSwitch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = AccountStorageScope(directory: root.appendingPathComponent("A"))
        let journal = try LocalSyncRepository(userID: "A", scope: a)
        a.syncRepository = journal
        let store = ReaderProfileStore(scope: a)
        let value = ReaderProfile.draft(username: "reader", preferredName: "Sabi", bio: "")
        #expect(store.save(value))
        #expect(ReaderProfileStore(scope: a).profile == value)
        #expect(journal.pending.contains { $0.entityID == "readerProfile" })
        let second = AccountStorageScope(directory: root.appendingPathComponent("second"))
        let remote = try LocalSyncRepository(userID: "A", scope: second)
        second.syncRepository = remote
        try remote.receive(journal.records)
        #expect(ReaderProfileStore(scope: second).profile == value)
        let b = ReaderProfileStore(scope: AccountStorageScope(directory: root.appendingPathComponent("B")))
        #expect(b.profile == nil)
        a.invalidate()
        #expect(!store.save(value))
        store.clear()
        #expect(store.profile == nil)
    }
}
