import Foundation
import Testing
import FirebaseFirestore
@testable import Book_App

@MainActor
struct CloudSyncTests {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func install(_ root: URL, user: String = "A") throws -> (AccountStorageScope, LocalSyncRepository) {
        let scope = AccountStorageScope(directory: root)
        let journal = try LocalSyncRepository(userID: user, scope: scope)
        scope.syncRepository = journal
        return (scope, journal)
    }

    private func book(_ title: String = "Original") -> Book {
        Book(id: "/works/OL123/W", title: title, authors: ["Author One", "Author Two"],
             description: "Complete metadata", coverURL: URL(string: "https://covers.openlibrary.org/b/id/123-L.jpg"),
             pageCount: 500, status: .reading, format: .audiobook, sourceBookID: "/works/OL123/W",
             completedAt: nil, progress: ReadingProgress(page: 123, percentage: 24.6, timestampSeconds: 987))
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        #expect(predicate())
    }

    @Test func signOutWaitsForServerAcknowledgementAndAllowsExplicitOfflineExit() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        let service = FakeCloudService()
        service.isOnline = false
        let sync = AccountSyncCoordinator(userID: "A", local: local, service: service)
        sync.start()
        let authService = SignOutAuthenticationService()
        let auth = AuthenticationState(service: authService)
        auth.start()
        let model = AccountViewModel(authentication: auth, sync: sync)
        model.requestSignOut()
        #expect(model.showsSignOutWarning)
        #expect(authService.signOutCount == 0)
        service.isOnline = true
        service.pauseAcknowledgement = true
        model.syncAndSignOut()
        await waitUntil { service.suspended != nil }
        model.syncStatusChanged()
        #expect(model.isWaitingToSignOut)
        #expect(authService.signOutCount == 0)
        service.resumeAcknowledgement()
        await waitUntil { sync.phase == .confirmed }
        model.syncStatusChanged()
        #expect(authService.signOutCount == 1)
        #expect(auth.session == .signedOut)
        sync.stop()
    }

    @Test func cancelledOrTimedOutSyncNeverLogsOutLaterAndPendingDataSurvivesForcedExit() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        let service = FakeCloudService()
        service.isOnline = false
        let sync = AccountSyncCoordinator(userID: "A", local: local, service: service)
        sync.start()
        let authService = SignOutAuthenticationService()
        let auth = AuthenticationState(service: authService)
        auth.start()
        let model = AccountViewModel(authentication: auth, sync: sync)
        model.syncAndSignOut()
        model.syncWaitExpired()
        #expect(!model.isWaitingToSignOut)
        #expect(model.errorMessage != nil)
        #expect(authService.signOutCount == 0)
        model.syncAndSignOut()
        model.cancelSignOut()
        model.syncStatusChanged()
        #expect(authService.signOutCount == 0)
        model.signOut()
        #expect(authService.signOutCount == 1)
        let (_, reopened) = try install(directory)
        #expect(reopened.pending.map(\.operationID) == local.pending.map(\.operationID))
        sync.stop()
    }

    @Test func syncFailureKeepsUserSignedInAndOldAccountCannotLogOutNewAccount() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        let service = FakeCloudService()
        service.commitFailure = .permissionDenied
        let sync = AccountSyncCoordinator(userID: "A", local: local, service: service)
        let authService = SignOutAuthenticationService()
        let auth = AuthenticationState(service: authService)
        auth.start()
        let model = AccountViewModel(authentication: auth, sync: sync)
        model.syncAndSignOut()
        await waitUntil { if case .failed = sync.phase { return true }; return false }
        model.syncStatusChanged()
        #expect(!model.isWaitingToSignOut)
        #expect(authService.signOutCount == 0)
        authService.callback?(.init(id: "B", email: "b@example.com"))
        model.signOut()
        #expect(authService.signOutCount == 0)
        #expect(auth.session == .signedIn(.init(id: "B", email: "b@example.com")))
        sync.stop()
    }

    @Test func confirmedAccountSignsOutWithoutWarning() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        let sync = AccountSyncCoordinator(userID: "A", local: local, service: FakeCloudService())
        sync.start()
        let authService = SignOutAuthenticationService()
        let auth = AuthenticationState(service: authService)
        auth.start()
        let model = AccountViewModel(authentication: auth, sync: sync)
        model.requestSignOut()
        #expect(!model.showsSignOutWarning)
        #expect(authService.signOutCount == 1)
        #expect(scope.isActive)
        sync.stop()
    }

    @Test func stableIDsArePathSafeAndTypeScoped() {
        let raw = "/works/OL123/W"
        let encoded = CloudRecord.documentID(for: raw)
        #expect(encoded.count == 64)
        #expect(!encoded.contains("/"))
        #expect(encoded == CloudRecord.documentID(for: raw))
        #expect(encoded != CloudRecord.documentID(for: "works/OL123/W"))
        let a = CloudRecord(collection: .books, entityID: raw, revision: 1, operationID: "op", payload: nil)
        let b = CloudRecord(collection: .reviews, entityID: raw, revision: 1, operationID: "op", payload: nil)
        #expect(a.key != b.key)
    }

    @Test func everyPersistedFieldRoundTripsToSecondDevice() async throws {
        let first = try root(), second = try root()
        defer { try? FileManager.default.removeItem(at: first); try? FileManager.default.removeItem(at: second) }
        let legacyScope = AccountStorageScope(directory: first)
        let original = book()
        let date = Date(timeIntervalSince1970: 1700000000)
        let progress = ReadingProgress(page: 160, percentage: 32, timestampSeconds: 1200)
        let session = ReadingSession(bookID: original.id, startedAt: date, endedAt: date.addingTimeInterval(600),
                                     pausedAt: nil, totalPausedSeconds: 45, startProgress: original.progress, endProgress: progress)
        let note = ReadingNote(bookID: original.id, text: "A saved note", page: 100, containsSpoilers: true, createdAt: date, updatedAt: date)
        let review = BookReview(bookID: original.id, rating: 4, text: "A full review", containsSpoilers: true, createdAt: date, updatedAt: date)
        let lists = [
            CustomBookList(name: "Second alphabetically", description: "First by user order", bookIDs: [original.id]),
            CustomBookList(name: "Alphabetically first", description: "Second by user order", bookIDs: [])
        ]
        try LocalLibraryDataSource(scope: legacyScope).saveBooks([original])
        try LocalReadingSessionDataSource(scope: legacyScope).saveSessions([session])
        try LocalBookContentDataSource(scope: legacyScope).saveContent(BookContentData(notes: [note], reviews: [review]))
        try LocalJSONRepository<[ReadingGoal]>(fileName: "reading-goals.json", scope: legacyScope).save([ReadingGoal(year: 2026, target: 30)])
        try LocalJSONRepository<[CustomBookList]>(fileName: "custom-book-lists.json", scope: legacyScope).save(lists)
        try LocalJSONRepository<ReadingReminderPreferences>(fileName: "reading-reminders.json", scope: legacyScope)
            .save(ReadingReminderPreferences(isEnabled: true, hour: 21, minute: 7))
        let (scopeA, localA) = try install(first)
        let service = FakeCloudService()
        let a = AccountSyncCoordinator(userID: "A", local: localA, service: service)
        a.start()
        await waitUntil { localA.pendingCount == 0 && localA.migrationComplete }
        let destination = try AccountSession(scope: AccountStorageScope(directory: second), userID: "A", cloudService: service)
        destination.sync?.start()
        await waitUntil { destination.libraryStore.books.count == 1 && destination.readingSessionStore.sessions.count == 1 }
        #expect(destination.libraryStore.books == [original])
        #expect(destination.readingSessionStore.sessions == [session])
        #expect(destination.bookContentStore.notes == [note])
        #expect(destination.bookContentStore.reviews == [review])
        #expect(try LocalJSONRepository<[CustomBookList]>(fileName: "custom-book-lists.json", scope: destination.scope).load(default: []) == lists)
        #expect(try LocalJSONRepository<[ReadingGoal]>(fileName: "reading-goals.json", scope: destination.scope).load(default: []) == [ReadingGoal(year: 2026, target: 30)])
        let restored = try LocalJSONRepository<ReadingReminderPreferences>(fileName: "reading-reminders.json", scope: destination.scope).load(default: .init())
        #expect(restored == ReadingReminderPreferences(isEnabled: true, hour: 21, minute: 7))
        // Projection files are real JSON; they are not just a transient Firestore cache.
        #expect(try JSONDecoder().decode([Book].self, from: Data(contentsOf: second.appendingPathComponent("library.json"))) == [original])
        #expect(scopeA.syncRepository?.pendingCount == 0)
        a.stop(); destination.invalidate()
    }

    @Test func staleMigrationCannotOverwriteExistingCloudAndIsIdempotent() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book("Stale local")])
        let (retainedScope, retainedLocal) = try install(directory)
        let cloud = CloudRecord(collection: .books, entityID: book().id, revision: 7,
                                operationID: UUID().uuidString, payload: try SyncEntityCodec.encode(book("New cloud")))
        let service = FakeCloudService()
        service.records["A"] = [cloud.key: cloud]
        let coordinator = AccountSyncCoordinator(userID: "A", local: retainedLocal, service: service)
        coordinator.start()
        await waitUntil { retainedLocal.pendingCount == 0 }
        #expect(service.records["A"]?[cloud.key] == cloud)
        #expect(try LocalLibraryDataSource(scope: retainedScope).loadBooks()?.first?.title == "New cloud")
        #expect(retainedLocal.conflicts.count == 1)
        let writes = service.writeCount
        coordinator.syncNow()
        await Task.yield()
        #expect(service.writeCount == writes)
        coordinator.stop()
    }

    @Test func serverRevisionConflictAndDeleteWinsWithoutClockDependence() throws {
        let original = CloudRecord(collection: .books, entityID: book().id, revision: 1,
                                   operationID: UUID().uuidString, payload: try SyncEntityCodec.encode(book()))
        let a = SyncMutation(collection: .books, entityID: book().id, operationID: UUID().uuidString,
                             baseRevision: 1, payload: try SyncEntityCodec.encode(book("A")), isMigration: false)
        let b = SyncMutation(collection: .books, entityID: book().id, operationID: UUID().uuidString,
                             baseRevision: 1, payload: try SyncEntityCodec.encode(book("B")), isMigration: false)
        let accepted = a.resolved(against: original)
        #expect(b.resolved(against: accepted) == accepted)
        #expect(a.resolved(against: accepted) == accepted)
        let deletion = SyncMutation(collection: .books, entityID: book().id, operationID: UUID().uuidString,
                                    baseRevision: 1, payload: nil, isMigration: false)
        let tombstone = deletion.resolved(against: accepted)
        #expect(tombstone.isDeleted)
        #expect(b.resolved(against: tombstone) == tombstone)
        let explicitRestore = SyncMutation(collection: .books, entityID: book().id, operationID: UUID().uuidString,
                                           baseRevision: tombstone.revision, payload: a.payload, isMigration: false)
        #expect(!explicitRestore.resolved(against: tombstone).isDeleted)
    }

    @Test func offlineQueueSurvivesRestartAndOnlyCompletesAfterServerConfirmation() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        let service = FakeCloudService()
        service.isOnline = false
        let coordinator = AccountSyncCoordinator(userID: "A", local: local, service: service)
        coordinator.start()
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        #expect(local.pendingCount == 2)
        #expect(!local.migrationComplete)
        #expect(service.writeCount == 0)
        let operationIDs = local.pending.map(\.operationID)
        coordinator.stop(); scope.invalidate()
        let (newScope, reopened) = try install(directory)
        #expect(reopened.pending.map(\.operationID) == operationIDs)
        #expect(try LocalLibraryDataSource(scope: newScope).loadBooks() == [book()])
        service.isOnline = true
        let retried = AccountSyncCoordinator(userID: "A", local: reopened, service: service)
        retried.start()
        await waitUntil { reopened.pendingCount == 0 && reopened.migrationComplete }
        #expect(service.writeCount == 2)
        retried.stop()
    }

    @Test func failedUploadRetainsPendingAndManualRetrySucceeds() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        let service = FakeCloudService()
        service.commitFailure = .permissionDenied
        let coordinator = AccountSyncCoordinator(userID: "A", local: local, service: service)
        coordinator.start()
        await waitUntil { if case .failed = coordinator.phase { return true }; return false }
        #expect(local.pendingCount > 0)
        #expect(!local.migrationComplete)
        service.commitFailure = nil
        coordinator.syncNow()
        await waitUntil { local.pendingCount == 0 }
        #expect(try LocalLibraryDataSource(scope: scope).loadBooks() == [book()])
        coordinator.stop()
    }

    @Test func emptySnapshotNeverDeletesLocalDataAndMalformedSiblingDoesNotBlockValidRecords() async throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book("Local")])
        let service = FakeCloudService()
        service.isOnline = false
        let coordinator = AccountSyncCoordinator(userID: "A", local: local, service: service)
        coordinator.start()
        service.deliver(user: "A", collection: .books, records: [], confirmed: true, invalid: ["broken"])
        #expect(try LocalLibraryDataSource(scope: scope).loadBooks()?.first?.title == "Local")
        let note = ReadingNote(bookID: book().id, text: "Valid sibling")
        let record = CloudRecord(collection: .notes, entityID: note.id.uuidString, revision: 1,
                                 operationID: UUID().uuidString, payload: try SyncEntityCodec.encode(note))
        service.deliver(user: "A", collection: .notes, records: [record], confirmed: true, invalid: ["bad-note"])
        #expect(try LocalBookContentDataSource(scope: scope).loadContent().notes == [note])
        #expect(!local.migrationComplete)
        if case .failed = coordinator.phase {} else { Issue.record("Malformed record must be visible as a recoverable sync error") }
        coordinator.stop()
    }

    @Test func localEditDuringUploadRemainsQueuedWithAdvancedBaseRevision() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book("First")])
        let first = try #require(local.pending.first { $0.collection == .books })
        try LocalLibraryDataSource(scope: scope).saveBooks([book("Second")])
        let winner = first.resolved(against: nil)
        try local.acknowledge(first, winner: winner)
        let next = try #require(local.pending.first { $0.collection == .books })
        #expect(next.baseRevision == winner.revision)
        #expect(next.operationID != first.operationID)
        #expect(try JSONDecoder().decode(Book.self, from: #require(next.payload)).title == "Second")
    }

    @Test func listenerDoesNotRebaseUnconfirmedMigrationOrCauseFeedbackWrites() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book("Local")])
        let remote = CloudRecord(collection: .books, entityID: book().id, revision: 9,
                                 operationID: UUID().uuidString, payload: try SyncEntityCodec.encode(book("Cloud")))
        try local.receive([remote])
        try LocalLibraryDataSource(scope: scope).saveBooks([book("Local edited before first upload")])
        let pending = try #require(local.pending.first { $0.collection == .books })
        #expect(pending.baseRevision == nil)
        #expect(pending.resolved(against: remote) == remote)
        try local.acknowledge(pending, winner: remote)
        let pendingCount = local.pendingCount
        try local.receive([remote])
        #expect(local.pendingCount == pendingCount)
        #expect(local.conflicts.count == 1)
    }

    @Test func deletionRetainsHistoryAndDoesNotResurrectFromOfflineDevice() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        let note = ReadingNote(bookID: book().id, text: "Keep history")
        try LocalBookContentDataSource(scope: scope).saveContent(BookContentData(notes: [note], reviews: []))
        for mutation in local.pending { try local.acknowledge(mutation, winner: mutation.resolved(against: nil)) }
        let stale = SyncMutation(collection: .books, entityID: book().id, operationID: UUID().uuidString,
                                 baseRevision: 1, payload: try SyncEntityCodec.encode(book("Old offline edit")), isMigration: false)
        try LocalLibraryDataSource(scope: scope).saveBooks([])
        let deletion = try #require(local.pending.first { $0.collection == .books })
        let server = try #require(local.records.first { $0.collection == .books })
        let tombstone = deletion.resolved(against: CloudRecord(collection: .books, entityID: server.entityID, revision: 1, operationID: "old", payload: stale.payload))
        try local.acknowledge(deletion, winner: tombstone)
        #expect(try LocalLibraryDataSource(scope: scope).loadBooks() == [])
        #expect(try LocalBookContentDataSource(scope: scope).loadContent().notes == [note])
        #expect(stale.resolved(against: tombstone).isDeleted)
    }

    @Test func signOutDuringInFlightCommitCannotWriteAnotherAccountOrAcknowledgeOldJournal() async throws {
        let directoryA = try root(), directoryB = try root()
        defer { try? FileManager.default.removeItem(at: directoryA); try? FileManager.default.removeItem(at: directoryB) }
        let (scopeA, localA) = try install(directoryA)
        try LocalLibraryDataSource(scope: scopeA).saveBooks([book("A only")])
        let service = FakeCloudService()
        service.pauseAcknowledgement = true
        let a = AccountSyncCoordinator(userID: "A", local: localA, service: service)
        a.start()
        await waitUntil { service.suspended != nil }
        a.stop(); scopeA.invalidate()
        let (scopeB, localB) = try install(directoryB, user: "B")
        let b = AccountSyncCoordinator(userID: "B", local: localB, service: service)
        b.start()
        service.resumeAcknowledgement()
        await Task.yield()
        #expect(localA.pendingCount > 0)
        #expect(try LocalLibraryDataSource(scope: scopeB).loadBooks() == [])
        #expect(service.records["B"]?.isEmpty ?? true)
        #expect(service.observations.values.filter { $0.user == "A" && !$0.cancelled }.isEmpty)
        b.stop()
    }

    @Test func replacedListenersCannotChangeCurrentSyncStatus() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        let service = FakeCloudService()
        let coordinator = AccountSyncCoordinator(userID: "A", local: local, service: service)
        coordinator.start()
        let old = Array(service.observations.values)
        coordinator.syncNow()
        for observation in old { observation.receive(.failure(.permissionDenied)) }
        #expect(coordinator.phase == .confirmed)
        #expect(scope.isActive)
        coordinator.stop()
    }

    @Test func firestoreEnvelopeRoundTripsAndRejectsMalformedIdentityAndVersion() throws {
        let record = CloudRecord(collection: .books, entityID: book().id, revision: 3,
                                 operationID: UUID().uuidString, payload: try SyncEntityCodec.encode(book()))
        var fields = try FirestoreRecordMapper.encode(record)
        fields["updatedAt"] = Timestamp(date: Date())
        let decoded = try FirestoreRecordMapper.decode(collection: .books, documentID: record.documentID, fields: fields)
        try SyncEntityCodec.validate(decoded)
        #expect(try JSONDecoder().decode(Book.self, from: #require(decoded.payload)) == book())
        #expect(throws: (any Error).self) {
            try FirestoreRecordMapper.decode(collection: .books, documentID: "wrong-path", fields: fields)
        }
        fields["schemaVersion"] = 2
        #expect(throws: (any Error).self) {
            try FirestoreRecordMapper.decode(collection: .books, documentID: record.documentID, fields: fields)
        }
    }

    @Test func reopeningRepairsInterruptedProjectionAndProtectsAccountIdentity() throws {
        let directory = try root()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (scope, local) = try install(directory)
        try LocalLibraryDataSource(scope: scope).saveBooks([book()])
        try Data("interrupted projection".utf8).write(to: directory.appendingPathComponent("library.json"))
        let (newScope, reopened) = try install(directory)
        #expect(try LocalLibraryDataSource(scope: newScope).loadBooks() == [book()])
        #expect(reopened.pending.map(\.operationID) == local.pending.map(\.operationID))
        #expect(throws: (any Error).self) { try LocalSyncRepository(userID: "B", scope: scope) }
    }
}

@MainActor
private final class SignOutAuthenticationService: AuthenticationService {
    final class Observation: AuthenticationObservation { func cancel() {} }
    var callback: (@MainActor (AuthenticatedUser?) -> Void)?
    var signOutCount = 0
    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation {
        callback = onChange
        onChange(.init(id: "A", email: "a@example.com"))
        return Observation()
    }
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String) async throws {}
    func signOut() throws { signOutCount += 1 }
}

@MainActor
private final class FakeCloudService: CloudSyncService {
    final class Observation: CloudSyncObservation {
        let user: String
        let collection: SyncCollection
        let receive: @MainActor (Result<CloudSnapshot, SyncFailure>) -> Void
        var cancelled = false
        init(user: String, collection: SyncCollection, receive: @escaping @MainActor (Result<CloudSnapshot, SyncFailure>) -> Void) {
            self.user = user; self.collection = collection; self.receive = receive
        }
        func cancel() { cancelled = true }
    }
    var records: [String: [String: CloudRecord]] = [:]
    var observations: [UUID: Observation] = [:]
    var isOnline = true
    var commitFailure: SyncFailure?
    var writeCount = 0
    var pauseAcknowledgement = false
    var suspended: CheckedContinuation<CloudRecord, Never>?
    var suspendedResult: CloudRecord?

    func observe(userID: String, collection: SyncCollection, lease: SyncSessionLease,
                 receive: @escaping @MainActor (Result<CloudSnapshot, SyncFailure>) -> Void) -> any CloudSyncObservation {
        let observation = Observation(user: userID, collection: collection, receive: receive)
        observations[UUID()] = observation
        receive(.success(CloudSnapshot(collection: collection, records: Array(records[userID, default: [:]].values).filter { $0.collection == collection },
                                       malformedDocumentIDs: [], isServerConfirmed: isOnline)))
        return observation
    }

    func commit(userID: String, mutation: SyncMutation, lease: SyncSessionLease) async throws -> CloudRecord {
        guard isOnline else { throw SyncFailure.unavailable }
        if let commitFailure { throw commitFailure }
        let current = records[userID]?[mutation.key]
        let winner = mutation.resolved(against: current)
        if winner != current {
            records[userID, default: [:]][winner.key] = winner
            writeCount += 1
        }
        deliver(user: userID, collection: mutation.collection,
                records: Array(records[userID, default: [:]].values).filter { $0.collection == mutation.collection })
        if pauseAcknowledgement {
            suspendedResult = winner
            return await withCheckedContinuation { suspended = $0 }
        }
        return winner
    }

    func deliver(user: String, collection: SyncCollection, records: [CloudRecord], confirmed: Bool = true, invalid: [String] = []) {
        for observation in observations.values where !observation.cancelled && observation.user == user && observation.collection == collection {
            observation.receive(.success(CloudSnapshot(collection: collection, records: records,
                                                       malformedDocumentIDs: invalid, isServerConfirmed: confirmed)))
        }
    }

    func resumeAcknowledgement() {
        pauseAcknowledgement = false
        if let suspendedResult { suspended?.resume(returning: suspendedResult) }
        suspended = nil; suspendedResult = nil
    }
}
