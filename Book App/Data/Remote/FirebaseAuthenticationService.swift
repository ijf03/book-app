import Foundation
import FirebaseAuth

@MainActor
final class FirebaseAuthenticationService: AuthenticationService {
    private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation {
        let observation = FirebaseAuthenticationObservation(auth: auth)
        observation.handle = auth.addStateDidChangeListener { [weak observation] _, user in
            let account = user.map { AuthenticatedUser(id: $0.uid, email: $0.email ?? "") }
            Task { @MainActor in
                guard let observation, observation.isActive,
                      observation.auth.currentUser?.uid == account?.id else { return }
                onChange(account)
            }
        }
        return observation
    }

    func signUp(email: String, password: String) async throws {
        // The backend is authoritative for the project's password policy.
        // Do not invent a local minimum or reject passwords based on a different policy.
        do { _ = try await auth.createUser(withEmail: email, password: password) }
        catch { throw map(error) }
    }

    func signIn(email: String, password: String) async throws {
        do { _ = try await auth.signIn(withEmail: email, password: password) }
        catch { throw map(error) }
    }

    func resetPassword(email: String) async throws {
        do { try await auth.sendPasswordReset(withEmail: email) }
        catch {
            // Keep reset responses neutral even when enumeration protection is disabled.
            if AuthErrorCode(rawValue: (error as NSError).code) == .userNotFound { return }
            throw map(error)
        }
    }

    func signOut() throws {
        do { try auth.signOut() }
        catch { throw map(error) }
    }

    private func map(_ error: Error) -> AuthenticationError {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .invalidEmail: .invalidEmail
        case .wrongPassword, .invalidCredential, .userNotFound: .invalidCredentials
        case .emailAlreadyInUse: .emailInUse
        case .weakPassword, .passwordDoesNotMeetRequirements: .passwordPolicy
        case .networkError: .offline
        case .tooManyRequests: .throttled
        case .userDisabled: .disabled
        case .operationNotAllowed: .unavailable
        default: .unknown
        }
    }
}

@MainActor
private final class FirebaseAuthenticationObservation: AuthenticationObservation {
    let auth: Auth
    var handle: AuthStateDidChangeListenerHandle?
    var isActive = true

    init(auth: Auth) { self.auth = auth }

    func cancel() {
        isActive = false
        if let handle { auth.removeStateDidChangeListener(handle) }
        handle = nil
    }

    deinit {
        if let handle { auth.removeStateDidChangeListener(handle) }
    }
}
