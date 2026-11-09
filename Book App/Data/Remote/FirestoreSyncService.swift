import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreSyncService: CloudSyncService {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) { self.database = database }

    func observe(userID: String, collection: SyncCollection, lease: SyncSessionLease,
                 receive: @escaping @MainActor (Result<CloudSnapshot, SyncFailure>) -> Void) -> any CloudSyncObservation {
        let reference = database.collection("users").document(userID).collection(collection.rawValue)
        let handle = reference.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            // The SDK delivers on its configured queue; all app state remains MainActor-isolated.
            Task { @MainActor in
                guard lease.isActive, lease.userID == userID else { return }
                if let error { receive(.failure(Self.map(error))); return }
                guard let snapshot else { receive(.failure(.unavailable)); return }
                var valid: [CloudRecord] = []
                var invalid: [String] = []
                for document in snapshot.documents {
                    do {
                        let record = try FirestoreRecordMapper.decode(
                            collection: collection, documentID: document.documentID, fields: document.data()
                        )
                        try SyncEntityCodec.validate(record)
                        valid.append(record)
                    } catch { invalid.append(document.documentID) }
                }
                receive(.success(CloudSnapshot(
                    collection: collection, records: valid, malformedDocumentIDs: invalid,
                    isServerConfirmed: !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites
                )))
            }
        }
        return FirestoreSyncObservation(handle: handle)
    }

    func commit(userID: String, mutation: SyncMutation, lease: SyncSessionLease) async throws -> CloudRecord {
        guard lease.isActive, lease.userID == userID else { throw SyncFailure.cancelled }
        let reference = database.collection("users").document(userID)
            .collection(mutation.collection.rawValue).document(CloudRecord.documentID(for: mutation.entityID))
        do {
            // No local/UI side effects inside this retryable transaction block.
            let result = try await database.runTransaction { transaction, errorPointer in
                do {
                    guard lease.isActive else { throw SyncFailure.cancelled }
                    let snapshot = try transaction.getDocument(reference)
                    let current = try snapshot.data().map {
                        try FirestoreRecordMapper.decode(collection: mutation.collection,
                                                         documentID: reference.documentID, fields: $0)
                    }
                    let winner = mutation.resolved(against: current)
                    guard lease.isActive else { throw SyncFailure.cancelled }
                    if winner.operationID == mutation.operationID && current?.operationID != mutation.operationID {
                        transaction.setData(try FirestoreRecordMapper.encode(winner), forDocument: reference)
                    }
                    return try JSONEncoder().encode(winner)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            guard lease.isActive else { throw SyncFailure.cancelled }
            guard let data = result as? Data else { throw SyncFailure.malformed }
            return try JSONDecoder().decode(CloudRecord.self, from: data)
        } catch {
            if let failure = error as? SyncFailure { throw failure }
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> SyncFailure {
        switch FirestoreErrorCode.Code(rawValue: (error as NSError).code) {
        case .permissionDenied, .unauthenticated: .permissionDenied
        case .cancelled: .cancelled
        default: .unavailable
        }
    }
}

@MainActor
private final class FirestoreSyncObservation: CloudSyncObservation {
    private var handle: ListenerRegistration?
    init(handle: ListenerRegistration) { self.handle = handle }
    func cancel() { handle?.remove(); handle = nil }
    deinit { handle?.remove() }
}
