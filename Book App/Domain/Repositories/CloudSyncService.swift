import Foundation

nonisolated struct CloudSnapshot: Sendable {
    let collection: SyncCollection
    let records: [CloudRecord]
    let malformedDocumentIDs: [String]
    let isServerConfirmed: Bool
}

@MainActor
protocol CloudSyncObservation: AnyObject { func cancel() }

@MainActor
protocol CloudSyncService {
    func observe(userID: String, collection: SyncCollection, lease: SyncSessionLease,
                 receive: @escaping @MainActor (Result<CloudSnapshot, SyncFailure>) -> Void) -> any CloudSyncObservation
    func commit(userID: String, mutation: SyncMutation, lease: SyncSessionLease) async throws -> CloudRecord
}

/// Accessed by Firestore's transaction worker as well as the main actor.
nonisolated final class SyncSessionLease: @unchecked Sendable {
    let userID: String
    let generation = UUID()
    private let lock = NSLock()
    private var active = true

    init(userID: String) { self.userID = userID }
    var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return active
    }
    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        active = false
    }
}
