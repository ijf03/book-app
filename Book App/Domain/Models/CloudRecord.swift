import Foundation
import CryptoKit

nonisolated enum SyncCollection: String, Codable, CaseIterable, Sendable {
    case books, sessions, notes, reviews, goals, lists, preferences
}

/// Payloads contain the complete Codable domain value as canonical JSON.
/// The Firestore adapter stores this as a map, never as an image or opaque blob.
nonisolated struct CloudRecord: Codable, Equatable, Sendable {
    var schemaVersion = 1
    let collection: SyncCollection
    let entityID: String
    let revision: Int
    let operationID: String
    let payload: Data?
    var isDeleted: Bool { payload == nil }
    var documentID: String { Self.documentID(for: entityID) }
    var key: String { collection.rawValue + "/" + documentID }

    static func documentID(for identity: String) -> String {
        SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct SyncMutation: Codable, Equatable, Sendable {
    let collection: SyncCollection
    let entityID: String
    let operationID: String
    var baseRevision: Int?
    let payload: Data?
    let isMigration: Bool
    var key: String { collection.rawValue + "/" + CloudRecord.documentID(for: entityID) }

    /// Server transactions call this pure function. Repeating an operation is idempotent.
    /// Deletion wins concurrent edits; recreation requires having observed the tombstone.
    func resolved(against current: CloudRecord?) -> CloudRecord {
        if let current, current.operationID == operationID { return current }
        if let current, current.revision != baseRevision, payload != nil { return current }
        if current == nil && baseRevision != nil {
            // A physically removed server record must not be recreated by a stale edit.
            return CloudRecord(collection: collection, entityID: entityID,
                               revision: baseRevision ?? 1, operationID: "missing-server-record", payload: nil)
        }
        return CloudRecord(collection: collection, entityID: entityID,
                           revision: (current?.revision ?? 0) + 1, operationID: operationID, payload: payload)
    }
}

nonisolated enum SyncFailure: Error, Equatable {
    case unavailable, permissionDenied, malformed, localStorage, cancelled

    var message: String {
        switch self {
        case .unavailable: String(localized: "Cloud unavailable. Your changes are saved on this device and will retry.")
        case .permissionDenied: String(localized: "Cloud access was denied. Your local data is safe. Check your account and published sync rules, then retry.")
        case .malformed: String(localized: "Some cloud records could not be read. Valid records and local data were kept. Retry after the records are repaired.")
        case .localStorage: String(localized: "Sync could not save local data. Free some device storage and retry.")
        case .cancelled: String(localized: "Sync stopped for this account.")
        }
    }
}
