import Foundation
import Testing
@testable import Book_App

@MainActor
struct AuthenticationTests {
    @Test func listenerIsRegisteredOnceAndClearsBeforePublishing() throws {
        let service = FakeAuthenticationService()
        let state = AuthenticationState(service: service)
        var cleared = 0
        state.willChangeAccount = { _ in cleared += 1 }
        #expect(state.session == .checkingSession)
        state.start()
        state.start()
        #expect(service.listenerCount == 1)
        service.emit(nil)
        #expect(state.session == .signedOut)
        let user = AuthenticatedUser(id: "A", email: "a@example.com")
        service.emit(user)
        #expect(state.session == .signedIn(user))
        service.emit(user)
        #expect(cleared == 2)
        try state.signOut()
        #expect(state.session == .signedOut)
        #expect(cleared == 3)
        state.stop()
        #expect(service.observation.cancelled)
    }

    @Test func trimsOnlyEmailAndPreservesPasswordExactly() async {
        let service = FakeAuthenticationService()
        let model = AuthenticationViewModel(service: service)
        model.email = "  reader@example.com\n"
        model.password = "  untouched password  "
        await model.submit()
        #expect(service.submittedEmail == "reader@example.com")
        #expect(service.submittedPassword == "  untouched password  ")
        #expect(model.password.isEmpty)
    }

    @Test func confirmationAndRequiredFieldsPreventNetworkCalls() async {
        let service = FakeAuthenticationService()
        let model = AuthenticationViewModel(service: service)
        await model.submit()
        #expect(service.requests == 0)
        model.changeMode(.signUp)
        model.email = "reader@example.com"
        model.password = "secret "
        model.confirmation = "secret"
        await model.submit()
        #expect(service.requests == 0)
        #expect(model.validation(.confirmation) != nil)
    }

    @Test func loginRequiresPassword() async {
        let service = FakeAuthenticationService()
        let model = AuthenticationViewModel(service: service)
        model.email = "unknown@example.com"
        await model.submit()
        #expect(service.requests == 0)
        #expect(model.validation(.password) != nil)
    }

    @Test func duplicateSubmissionIsIgnoredAndOfflineErrorIsFriendly() async {
        let service = FakeAuthenticationService()
        service.shouldSuspend = true
        let model = AuthenticationViewModel(service: service)
        model.email = "reader@example.com"
        model.password = "secret"
        let first = Task { await model.submit() }
        while service.pending == nil { await Task.yield() }
        await model.submit()
        #expect(service.requests == 1)
        #expect(model.isLoading)
        service.pending?.resume(throwing: AuthenticationError.offline)
        service.pending = nil
        await first.value
        #expect(model.submission == .failed(AuthenticationError.offline.message))
        #expect(!model.isLoading)
    }

    @Test func accountCopiesAreIsolatedAndLegacyBytesArePreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = AccountStorageScope(directory: root)
        try LocalLibraryDataSource(scope: legacy).saveBooks([Book.mockFourthWing])
        try LocalReadingSessionDataSource(scope: legacy).saveSessions([])
        try LocalBookContentDataSource(scope: legacy).saveContent(.empty)
        try LocalJSONRepository<[ReadingGoal]>(fileName: "reading-goals.json", scope: legacy)
            .save([ReadingGoal(year: 2026, target: 20)])
        try LocalJSONRepository<[CustomBookList]>(fileName: "custom-book-lists.json", scope: legacy)
            .save([CustomBookList(name: "Legacy", description: "", bookIDs: [])])
        try LocalJSONRepository<ReadingReminderPreferences>(fileName: "reading-reminders.json", scope: legacy)
            .save(ReadingReminderPreferences(isEnabled: true, hour: 19, minute: 30))
        let originals = try Dictionary(uniqueKeysWithValues: AccountLocalStorage.legacyFileNames.map {
            ($0, try Data(contentsOf: root.appendingPathComponent($0)))
        })
        let storage = try AccountLocalStorage(root: root)
        #expect(storage.needsLegacyChoice(for: "A"))
        let a = try storage.prepare(userID: "A", importLegacy: true)
        let b = try storage.prepare(userID: "B", importLegacy: false)
        #expect(a.directory != b.directory)
        #expect(try LocalLibraryDataSource(scope: a).loadBooks() == [Book.mockFourthWing])
        #expect(try LocalLibraryDataSource(scope: b).loadBooks() == nil)
        for name in AccountLocalStorage.legacyFileNames {
            #expect(try Data(contentsOf: a.directory.appendingPathComponent(name)) == originals[name])
            #expect(try Data(contentsOf: root.appendingPathComponent(name)) == originals[name])
            #expect(!FileManager.default.fileExists(atPath: b.directory.appendingPathComponent(name).path))
        }
        try LocalLibraryDataSource(scope: a).saveBooks([])
        #expect(try LocalLibraryDataSource(scope: b).loadBooks() == nil)
        let reopened = try storage.prepare(userID: "A", importLegacy: true)
        #expect(try LocalLibraryDataSource(scope: reopened).loadBooks() == [])
        #expect(!storage.needsLegacyChoice(for: "A"))
        #expect(!storage.needsLegacyChoice(for: "B"))
        #expect(try Data(contentsOf: root.appendingPathComponent("library.json")) == originals["library.json"])
    }

    @Test func revokedScopeRejectsLateWritesAndClearsStores() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try AccountLocalStorage(root: root)
        let scope = try storage.prepare(userID: "A", importLegacy: false)
        try LocalLibraryDataSource(scope: scope).saveBooks([Book.mockFourthWing])
        let session = try AccountSession(scope: scope)
        let before = try Data(contentsOf: scope.directory.appendingPathComponent("library.json"))
        session.invalidate()
        #expect(session.libraryStore.books.isEmpty)
        #expect(session.readingSessionStore.sessions.isEmpty)
        #expect(session.bookContentStore.notes.isEmpty)
        #expect(session.bookContentStore.reviews.isEmpty)
        #expect(throws: (any Error).self) { try LocalLibraryDataSource(scope: scope).saveBooks([]) }
        #expect(throws: (any Error).self) {
            try LocalJSONRepository<[ReadingGoal]>(fileName: "reading-goals.json", scope: scope).save([])
        }
        #expect(try Data(contentsOf: scope.directory.appendingPathComponent("library.json")) == before)
    }

    @Test func failedLegacyImportDoesNotPublishOrModifyOriginals() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let corrupt = Data("not JSON".utf8)
        try corrupt.write(to: root.appendingPathComponent("library.json"))
        let storage = try AccountLocalStorage(root: root)
        #expect(throws: (any Error).self) { try storage.prepare(userID: "A", importLegacy: true) }
        #expect(!FileManager.default.fileExists(atPath: storage.directory(for: "A").path))
        #expect(try Data(contentsOf: root.appendingPathComponent("library.json")) == corrupt)
        #expect(storage.needsLegacyChoice(for: "A"))
        _ = try storage.prepare(userID: "A", importLegacy: false)
        #expect(try Data(contentsOf: root.appendingPathComponent("library.json")) == corrupt)
    }
}

@MainActor
private final class FakeAuthenticationService: AuthenticationService {
    let observation = FakeAuthenticationObservation()
    var listenerCount = 0
    var requests = 0
    var submittedEmail: String?
    var submittedPassword: String?
    var shouldSuspend = false
    var pending: CheckedContinuation<Void, Error>?
    var callback: (@MainActor (AuthenticatedUser?) -> Void)?

    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation {
        listenerCount += 1
        callback = onChange
        return observation
    }
    func emit(_ user: AuthenticatedUser?) { callback?(user) }
    func signUp(email: String, password: String) async throws { try await signIn(email: email, password: password) }
    func signIn(email: String, password: String) async throws {
        requests += 1
        submittedEmail = email
        submittedPassword = password
        if shouldSuspend { try await withCheckedThrowingContinuation { pending = $0 } }
    }
    func signOut() throws {}
}

@MainActor
private final class FakeAuthenticationObservation: AuthenticationObservation {
    var cancelled = false
    func cancel() { cancelled = true }
}
