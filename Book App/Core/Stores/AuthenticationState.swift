import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationState {
    enum Session: Equatable {
        case checkingSession
        case signedOut
        case signedIn(AuthenticatedUser)
    }

    private(set) var session: Session = .checkingSession
    private(set) var generation = UUID()
    private let service: any AuthenticationService
    @ObservationIgnored private var observation: (any AuthenticationObservation)?
    @ObservationIgnored var willChangeAccount: ((AuthenticatedUser?) -> Void)?

    init(service: any AuthenticationService) { self.service = service }

    func start() {
        guard observation == nil else { return }
        observation = service.observeSession { [weak self] user in
            guard let self else { return }
            let next: Session = user.map { .signedIn($0) } ?? .signedOut
            guard next != self.session else { return }
            if self.userID != user?.id || self.session == .checkingSession {
                self.generation = UUID()
                self.willChangeAccount?(user)
            }
            self.session = next
        }
    }

    var userID: String? {
        guard case .signedIn(let user) = session else { return nil }
        return user.id
    }

    func changeEmail(_ email: String, password: String) async throws {
        guard let id = userID else { throw AuthenticationError.invalidCredentials }
        let original = generation
        try await service.changeEmail(userID: id, email: email, currentPassword: password)
        guard original == generation else { throw CancellationError() }
        session = .signedIn(AuthenticatedUser(id: id, email: email))
    }

    func changePassword(current: String, new: String) async throws {
        guard let id = userID else { throw AuthenticationError.invalidCredentials }
        let original = generation
        try await service.changePassword(userID: id, currentPassword: current, newPassword: new)
        guard original == generation else { throw CancellationError() }
    }

    func refreshUser() async throws {
        guard let id = userID else { throw AuthenticationError.invalidCredentials }
        let original = generation
        let user = try await service.refreshedUser(userID: id)
        guard original == generation, user.id == id else { throw CancellationError() }
        session = .signedIn(user)
    }

    func stop() {
        generation = UUID()
        observation?.cancel()
        observation = nil
        willChangeAccount?(nil)
        session = .checkingSession
    }

    func signOut() throws {
        try service.signOut()
        generation = UUID()
        // Clear immediately; the listener remains the authority for subsequent sessions.
        willChangeAccount?(nil)
        session = .signedOut
    }
}
