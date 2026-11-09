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
            self.willChangeAccount?(user)
            self.session = next
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
        willChangeAccount?(nil)
        session = .checkingSession
    }

    func signOut() throws {
        try service.signOut()
        // Clear immediately; the listener remains the authority for subsequent sessions.
        willChangeAccount?(nil)
        session = .signedOut
    }
}
