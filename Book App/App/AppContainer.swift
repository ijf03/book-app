import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    enum StorageState: Equatable {
        case unavailable, needsLegacyChoice, ready, failed
    }

    let authenticationService: any AuthenticationService
    let authentication: AuthenticationState
    let bookRepository: any BookRepository
    private(set) var account: AccountSession?
    private(set) var storageState: StorageState = .unavailable

    init(authenticationService: (any AuthenticationService)? = nil) {
        let service = authenticationService ?? FirebaseAuthenticationService()
        self.authenticationService = service
        authentication = AuthenticationState(service: service)
        bookRepository = DefaultBookRepository(remoteDataSource: OpenLibraryRemoteDataSource())
        authentication.willChangeAccount = { [weak self] user in
            self?.changeAccount(user)
        }
        authentication.start()
    }

    private func changeAccount(_ user: AuthenticatedUser?) {
        account?.invalidate()
        account = nil
        LocalReadingNotificationService().cancel()
        storageState = .unavailable
        guard let user else { return }
        prepareAccount(user: user, importLegacy: nil)
    }

    func chooseLegacyImport(_ importLegacy: Bool) {
        guard case .signedIn(let user) = authentication.session else { return }
        prepareAccount(user: user, importLegacy: importLegacy)
    }

    func retryStorage() {
        guard case .signedIn(let user) = authentication.session else { return }
        prepareAccount(user: user, importLegacy: nil)
    }

    private func prepareAccount(user: AuthenticatedUser, importLegacy: Bool?) {
        do {
            let storage = try AccountLocalStorage()
            if importLegacy == nil && storage.needsLegacyChoice(for: user.id) {
                storageState = .needsLegacyChoice
                return
            }
            let scope = try storage.prepare(userID: user.id, importLegacy: importLegacy ?? false)
            account = try AccountSession(scope: scope)
            storageState = .ready
        } catch {
            account = nil
            storageState = .failed
        }
    }
}
