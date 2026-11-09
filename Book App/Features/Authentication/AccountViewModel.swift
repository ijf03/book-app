import Foundation
import Observation

@MainActor
@Observable
final class AccountViewModel {
    private(set) var errorMessage: String?
    let authentication: AuthenticationState
    let sync: AccountSyncCoordinator?
    var showsSignOutWarning = false
    private(set) var isWaitingToSignOut = false
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    init(authentication: AuthenticationState, sync: AccountSyncCoordinator? = nil) {
        self.authentication = authentication
        self.sync = sync
    }

    var needsSyncBeforeSignOut: Bool {
        guard let sync else { return false }
        return sync.phase != .confirmed || sync.local.pendingCount > 0 || !sync.local.conflicts.isEmpty
    }

    func requestSignOut() {
        guard !isWaitingToSignOut else { return }
        errorMessage = nil
        if needsSyncBeforeSignOut { showsSignOutWarning = true }
        else { signOut() }
    }

    func syncAndSignOut() {
        guard !isWaitingToSignOut, let sync, isCurrentAccount else { return }
        showsSignOutWarning = false
        errorMessage = nil
        isWaitingToSignOut = true
        sync.syncNow()
        syncStatusChanged()
        guard isWaitingToSignOut else { return }
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) }
            catch { return }
            self?.syncWaitExpired()
        }
    }

    func syncStatusChanged() {
        guard isWaitingToSignOut else { return }
        guard isCurrentAccount, let sync else { cancelSignOut(); return }
        if case .failed(let message) = sync.phase {
            cancelSignOut()
            errorMessage = message
        } else if sync.phase == .confirmed, sync.local.pendingCount == 0 {
            if sync.local.conflicts.isEmpty { signOut() }
            else {
                cancelSignOut()
                errorMessage = String(localized: "Review your conflicting edits before syncing and signing out, or choose Sign out anyway. Your saved copies stay on this device.")
            }
        }
    }

    func syncWaitExpired() {
        guard isWaitingToSignOut else { return }
        cancelSignOut()
        errorMessage = String(localized: "Sync hasn’t been confirmed yet. You’re still signed in. Check your connection and try again, or sign out anyway. Your pending changes stay on this device.")
    }

    func cancelSignOut() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isWaitingToSignOut = false
        showsSignOutWarning = false
    }

    private var isCurrentAccount: Bool {
        guard let sync else { return true }
        guard sync.lease.isActive, case .signedIn(let user) = authentication.session else { return false }
        return user.id == sync.lease.userID
    }

    var email: String {
        guard case .signedIn(let user) = authentication.session else { return "" }
        return user.email
    }

    func signOut() {
        guard isCurrentAccount else { cancelSignOut(); return }
        cancelSignOut()
        do { try authentication.signOut(); errorMessage = nil }
        catch { errorMessage = (error as? AuthenticationError ?? .unknown).message }
    }
}
