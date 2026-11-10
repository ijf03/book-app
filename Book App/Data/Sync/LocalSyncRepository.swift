import Foundation
import Observation

/// The atomic journal is authoritative once installed. The six JSON files are
/// projections for the existing features, rebuilt from the journal after a crash.
@MainActor
@Observable
final class LocalSyncRepository {
    struct Entry: Codable {
        var server: CloudRecord?
        var pending: SyncMutation?
        var failure: String?

        var visible: CloudRecord? {
            if let pending {
                return CloudRecord(collection: pending.collection, entityID: pending.entityID,
                                   revision: (pending.baseRevision ?? 0) + 1,
                                   operationID: pending.operationID, payload: pending.payload)
            }
            return server
        }
    }

    struct Conflict: Codable, Identifiable {
        let id: UUID
        let rejected: SyncMutation
        let winner: CloudRecord
        let detectedAt: Date
    }

    private struct Journal: Codable {
        var schemaVersion = 1
        let userID: String
        var entries: [String: Entry] = [:]
        var conflicts: [Conflict] = []
        var migrationComplete = false
    }

    @ObservationIgnored private weak var scope: AccountStorageScope?
    @ObservationIgnored private var journal: Journal
    @ObservationIgnored var onLocalChange: (() -> Void)?
    @ObservationIgnored var onRemoteChange: (() -> Void)?
    private(set) var pendingCount = 0
    private(set) var conflicts: [Conflict] = []
    private(set) var projectionError: String?
    private(set) var migrationComplete = false
    private let directory: URL
    private var journalURL: URL { directory.appendingPathComponent("sync-journal-v1.json") }

    init(userID: String, scope: AccountStorageScope) throws {
        self.scope = scope
        directory = scope.directory
        journal = Journal(userID: userID)
        if FileManager.default.fileExists(atPath: journalURL.path) {
            journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
            guard journal.schemaVersion == 1, journal.userID == userID else { throw SyncFailure.malformed }
            for entry in journal.entries.values {
                if let record = entry.visible { try SyncEntityCodec.validate(record) }
            }
        } else {
            for file in AccountLocalStorage.accountFileNames {
                let url = directory.appendingPathComponent(file)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                for entity in try SyncEntityCodec.entities(file: file, data: Data(contentsOf: url)) {
                    guard journal.entries[entity.key] == nil else { throw SyncFailure.malformed }
                    let mutation = SyncMutation(collection: entity.collection, entityID: entity.id,
                                                operationID: UUID().uuidString, baseRevision: nil,
                                                payload: entity.payload, isMigration: true)
                    let entry = Entry(pending: mutation)
                    if let visible = entry.visible { try SyncEntityCodec.validate(visible) }
                    journal.entries[entity.key] = entry
                }
            }
            try persist(journal)
        }
        refreshPublishedState()
        materialize()
    }

    var pending: [SyncMutation] {
        journal.entries.values.compactMap(\.pending).sorted { $0.key < $1.key }
    }

    var records: [CloudRecord] { journal.entries.values.compactMap(\.visible) }

    func data(for file: String) throws -> Data {
        try checkAccess()
        return try SyncEntityCodec.projection(file: file, records: records)
    }

    /// A user save diffs only its file. Missing cloud documents never call this method.
    func save(file: String, data: Data) throws {
        try checkAccess()
        let entities = try SyncEntityCodec.entities(file: file, data: data)
        guard Set(entities.map(\.key)).count == entities.count else { throw SyncFailure.malformed }
        var next = journal
        let suppliedKeys = Set(entities.map(\.key))
        for entity in entities {
            let old = next.entries[entity.key]
            if old?.visible?.payload == entity.payload { continue }
            let pending = SyncMutation(collection: entity.collection, entityID: entity.id,
                                       operationID: UUID().uuidString,
                                       baseRevision: old?.pending != nil ? old?.pending?.baseRevision : old?.server?.revision,
                                       payload: entity.payload, isMigration: old?.pending?.isMigration ?? false)
            let updated = Entry(server: old?.server, pending: pending)
            if let visible = updated.visible { try SyncEntityCodec.validate(visible) }
            next.entries[entity.key] = updated
        }
        for (key, entry) in journal.entries {
            guard let visible = entry.visible, !visible.isDeleted,
                  SyncEntityCodec.file(for: visible.collection, id: visible.entityID) == file,
                  !suppliedKeys.contains(key) else { continue }
            next.entries[key] = Entry(server: entry.server, pending: SyncMutation(
                collection: visible.collection, entityID: visible.entityID,
                operationID: UUID().uuidString,
                baseRevision: entry.pending != nil ? entry.pending?.baseRevision : entry.server?.revision,
                payload: nil, isMigration: entry.pending?.isMigration ?? false
            ))
        }
        try persist(next)
        journal = next
        refreshPublishedState()
        materialize()
        onLocalChange?()
    }

    /// Listeners only advance confirmed revisions. Pending user edits are held
    /// until the transaction resolves them, never blindly overwritten by a listener.
    func receive(_ records: [CloudRecord]) throws {
        try checkAccess()
        var next = journal
        var changed = false
        for record in records {
            try SyncEntityCodec.validate(record)
            var entry = next.entries[record.key] ?? Entry()
            guard record.revision > (entry.server?.revision ?? 0) else { continue }
            entry.server = record
            // Do NOT clear pending here: the matching transaction may still be running.
            next.entries[record.key] = entry
            changed = true
        }
        guard changed else { return }
        try persist(next)
        journal = next
        refreshPublishedState()
        materialize()
        onRemoteChange?()
    }

    /// Called only after the transaction completes against the server, not a cache.
    func acknowledge(_ submitted: SyncMutation, winner: CloudRecord) throws {
        try checkAccess()
        try SyncEntityCodec.validate(winner)
        guard winner.key == submitted.key else { throw SyncFailure.malformed }
        var next = journal
        var entry = next.entries[submitted.key] ?? Entry()
        // A listener may already have received a newer server revision.
        let newest = (entry.server?.revision ?? 0) > winner.revision ? entry.server : winner
        entry.server = newest
        if winner.operationID == submitted.operationID {
            if entry.pending?.operationID == submitted.operationID {
                entry.pending = nil
            } else if var newerEdit = entry.pending {
                // Edits made during our own upload causally follow that upload.
                newerEdit.baseRevision = winner.revision
                entry.pending = newerEdit
            }
        } else if let rejected = entry.pending {
            if rejected.payload != winner.payload {
                next.conflicts.append(Conflict(id: UUID(), rejected: rejected, winner: winner, detectedAt: Date()))
            }
            entry.pending = nil
        }
        entry.failure = nil
        next.entries[submitted.key] = entry
        try persist(next)
        journal = next
        refreshPublishedState()
        materialize()
        onRemoteChange?()
    }

    func recordFailure(_ mutation: SyncMutation, message: String) throws {
        try checkAccess()
        var next = journal
        guard next.entries[mutation.key]?.pending != nil else { return }
        next.entries[mutation.key]?.failure = message
        try persist(next)
        journal = next
    }

    func completeMigration() throws {
        try checkAccess()
        guard pending.isEmpty, !journal.migrationComplete else { return }
        var next = journal
        next.migrationComplete = true
        try persist(next)
        journal = next
        refreshPublishedState()
    }

    func restoreConflict(id: UUID) throws {
        try checkAccess()
        guard let conflict = journal.conflicts.first(where: { $0.id == id }) else { return }
        var next = journal
        let old = next.entries[conflict.rejected.key]
        next.entries[conflict.rejected.key] = Entry(server: old?.server, pending: SyncMutation(
            collection: conflict.rejected.collection, entityID: conflict.rejected.entityID,
            operationID: UUID().uuidString, baseRevision: old?.server?.revision,
            payload: conflict.rejected.payload, isMigration: false
        ))
        next.conflicts.removeAll { $0.id == id }
        try persist(next)
        journal = next
        refreshPublishedState()
        materialize()
        onRemoteChange?()
        onLocalChange?()
    }

    func discardConflict(id: UUID) throws {
        var next = journal
        next.conflicts.removeAll { $0.id == id }
        try persist(next)
        journal = next
        refreshPublishedState()
    }

    func repairProjections() { materialize() }

    private func checkAccess() throws {
        guard let scope else { throw SyncFailure.cancelled }
        try scope.checkAccess()
    }

    private func persist(_ value: Journal) throws {
        try checkAccess()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SyncEntityCodec.encode(value).write(to: journalURL, options: .atomic)
    }

    private func refreshPublishedState() {
        pendingCount = pending.count
        conflicts = journal.conflicts
        migrationComplete = journal.migrationComplete
    }

    private func materialize() {
        do {
            try checkAccess()
            for file in AccountLocalStorage.accountFileNames {
                try data(for: file).write(to: directory.appendingPathComponent(file), options: .atomic)
            }
            projectionError = nil
        } catch {
            // The atomic journal has already saved the edit. Reads use it directly;
            // projection repair is safe on the next launch or explicit retry.
            projectionError = SyncFailure.localStorage.message
        }
    }
}
