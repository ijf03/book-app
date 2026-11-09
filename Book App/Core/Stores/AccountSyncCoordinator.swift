import Foundation
import Observation

@MainActor
@Observable
final class AccountSyncCoordinator {
    enum Phase: Equatable { case locallySaved, pending, syncing, confirmed, failed(String), stopped }

    let local: LocalSyncRepository
    let lease: SyncSessionLease
    private(set) var phase: Phase = .locallySaved
    private(set) var lastConfirmedAt: Date?
    @ObservationIgnored private let service: any CloudSyncService
    @ObservationIgnored private var observations: [any CloudSyncObservation] = []
    @ObservationIgnored private var confirmedCollections: Set<SyncCollection> = []
    @ObservationIgnored private var malformed: Set<SyncCollection> = []
    @ObservationIgnored private var failures: [SyncCollection: SyncFailure] = [:]
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryDelay: UInt64 = 5
    @ObservationIgnored private var observationGeneration = UUID()

    init(userID: String, local: LocalSyncRepository, service: any CloudSyncService) {
        self.local = local
        self.service = service
        lease = SyncSessionLease(userID: userID)
        local.onLocalChange = { [weak self] in self?.kick() }
    }

    func start() {
        guard lease.isActive, observations.isEmpty else { return }
        attach()
    }

    func stop() {
        lease.invalidate()
        observations.forEach { $0.cancel() }
        observations = []
        worker?.cancel(); worker = nil
        retryTask?.cancel(); retryTask = nil
        local.onLocalChange = nil
        local.onRemoteChange = nil
        phase = .stopped
    }

    func syncNow() {
        guard lease.isActive else { return }
        local.repairProjections()
        retryTask?.cancel(); retryTask = nil
        observations.forEach { $0.cancel() }
        observations = []
        confirmedCollections = []
        failures = [:]
        attach()
    }

    func restoreConflict(id: UUID) {
        do { try local.restoreConflict(id: id) }
        catch { phase = .failed(SyncFailure.localStorage.message) }
    }

    func keepCloudVersion(id: UUID) {
        do { try local.discardConflict(id: id) }
        catch { phase = .failed(SyncFailure.localStorage.message) }
    }

    private func attach() {
        observationGeneration = UUID()
        let generation = observationGeneration
        for collection in SyncCollection.allCases {
            observations.append(service.observe(userID: lease.userID, collection: collection, lease: lease) { [weak self] result in
                guard let self, self.lease.isActive, self.observationGeneration == generation else { return }
                self.receive(result, collection: collection)
            })
        }
        refreshPhase()
    }

    private func receive(_ result: Result<CloudSnapshot, SyncFailure>, collection: SyncCollection) {
        switch result {
        case .failure(let error):
            failures[collection] = error
            confirmedCollections.remove(collection)
            scheduleRetry()
        case .success(let snapshot):
            guard snapshot.collection == collection else { return }
            // Local JSON/journal supplies offline data. Firestore cache is never
            // treated as server confirmation, migration completion, or deletion.
            guard snapshot.isServerConfirmed else {
                confirmedCollections.remove(collection)
                refreshPhase()
                return
            }
            confirmedCollections.insert(collection)
            failures[collection] = nil
            if snapshot.malformedDocumentIDs.isEmpty { malformed.remove(collection) }
            else { malformed.insert(collection) }
            do { try local.receive(snapshot.records) }
            catch { failures[collection] = .localStorage }
            retryDelay = 5
        }
        kick()
    }

    private func kick() {
        guard lease.isActive else { return }
        refreshPhase()
        guard worker == nil,
              local.pending.contains(where: { confirmedCollections.contains($0.collection) && failures[$0.collection] == nil }) else { return }
        worker = Task { [weak self] in
            guard let self else { return }
            await self.drain()
        }
    }

    private func drain() async {
        defer { worker = nil; refreshPhase() }
        // Each iteration obtains the latest operation; edits during an upload
        // remain pending under a new operation ID.
        while lease.isActive && !Task.isCancelled {
            guard let mutation = local.pending.first(where: {
                confirmedCollections.contains($0.collection) && failures[$0.collection] == nil
            }) else { break }
            phase = .syncing
            do {
                let winner = try await service.commit(userID: lease.userID, mutation: mutation, lease: lease)
                guard lease.isActive, !Task.isCancelled else { return }
                try local.acknowledge(mutation, winner: winner)
            } catch {
                guard lease.isActive, !Task.isCancelled else { return }
                let failure = error as? SyncFailure ?? .localStorage
                failures[mutation.collection] = failure
                do { try local.recordFailure(mutation, message: failure.message) }
                catch { failures[mutation.collection] = .localStorage }
                scheduleRetry()
            }
        }
    }

    private func refreshPhase() {
        guard lease.isActive else { phase = .stopped; return }
        if let message = local.projectionError { phase = .failed(message); return }
        if let failure = failures.values.first { phase = .failed(failure.message); return }
        if !malformed.isEmpty { phase = .failed(SyncFailure.malformed.message); return }
        if !local.pending.isEmpty {
            phase = worker == nil ? .pending : .syncing
        } else if confirmedCollections.count == SyncCollection.allCases.count {
            do {
                try local.completeMigration()
                phase = .confirmed
                lastConfirmedAt = Date()
            } catch { phase = .failed(SyncFailure.localStorage.message) }
        } else {
            phase = .locallySaved
        }
    }

    private func scheduleRetry() {
        guard lease.isActive, retryTask == nil else { return }
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 60)
        retryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard let self, self.lease.isActive else { return }
            self.retryTask = nil
            self.syncNow()
        }
    }
}
