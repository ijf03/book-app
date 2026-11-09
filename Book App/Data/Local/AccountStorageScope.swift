import Foundation
import Observation

/// Immutable destination plus a revocable lease. Old async work cannot write after sign-out.
@MainActor
@Observable
final class AccountStorageScope {
    let directory: URL
    private(set) var isActive = true
    private(set) var cloudRevision = 0
    var syncRepository: LocalSyncRepository?

    init(directory: URL) { self.directory = directory }
    func invalidate() { isActive = false }
    func checkAccess() throws {
        guard isActive else { throw CocoaError(.userCancelled) }
    }

    func syncedData(file: String) throws -> Data? {
        try checkAccess()
        return try syncRepository?.data(for: file)
    }

    func save(_ data: Data, to url: URL) throws {
        try checkAccess()
        if let syncRepository { try syncRepository.save(file: url.lastPathComponent, data: data) }
        else { try data.write(to: url, options: .atomic) }
    }

    func publishCloudChange() { cloudRevision += 1 }
}
