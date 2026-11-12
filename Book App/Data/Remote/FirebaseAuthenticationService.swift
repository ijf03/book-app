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

    private func reauthenticate(userID: String, password: String) async throws -> User {
        guard let user = auth.currentUser, user.uid == userID, let email = user.email else { throw AuthenticationError.invalidCredentials }
        try Task.checkCancellation()
        _ = try await user.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password))
        try Task.checkCancellation()
        guard auth.currentUser === user else { throw AuthenticationError.invalidCredentials }
        return user
    }

    func changeEmail(userID: String, email: String, currentPassword: String) async throws {
        do {
            let user = try await reauthenticate(userID: userID, password: currentPassword)
            // Direct changes require the Firebase project to allow this operation.
            try await user.updateEmail(to: email)
        } catch {
            if AuthErrorCode(rawValue: (error as NSError).code) == .operationNotAllowed {
                throw AuthenticationError.emailChangeUnavailable
            }
            throw (error as? AuthenticationError) ?? map(error)
        }
    }

    func changePassword(userID: String, currentPassword: String, newPassword: String) async throws {
        do {
            let user = try await reauthenticate(userID: userID, password: currentPassword)
            try await user.updatePassword(to: newPassword)
        } catch { throw (error as? AuthenticationError) ?? map(error) }
    }

    func refreshedUser(userID: String) async throws -> AuthenticatedUser {
        do {
            guard let user = auth.currentUser, user.uid == userID else { throw AuthenticationError.invalidCredentials }
            try await user.reload()
            try Task.checkCancellation()
            guard auth.currentUser === user else { throw AuthenticationError.invalidCredentials }
            return AuthenticatedUser(id: user.uid, email: user.email ?? "")
        } catch { throw (error as? AuthenticationError) ?? map(error) }
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
