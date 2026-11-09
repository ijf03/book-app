import Foundation

/// Immutable destination plus a revocable lease. Old async work cannot write after sign-out.
@MainActor
final class AccountStorageScope {
    let directory: URL
    private(set) var isActive = true

    init(directory: URL) { self.directory = directory }
    func invalidate() { isActive = false }
    func checkAccess() throws {
        guard isActive else { throw CocoaError(.userCancelled) }
    }
}
