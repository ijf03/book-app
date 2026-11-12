import Foundation

@MainActor
protocol AuthenticationService: AnyObject {
    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func changeEmail(userID: String, email: String, currentPassword: String) async throws
    func changePassword(userID: String, currentPassword: String, newPassword: String) async throws
    func refreshedUser(userID: String) async throws -> AuthenticatedUser
    func signOut() throws
}

@MainActor
protocol AuthenticationObservation: AnyObject {
    func cancel()
}

// Existing test doubles and alternative providers may not support account editing.
extension AuthenticationService {
    func changeEmail(userID: String, email: String, currentPassword: String) async throws { throw AuthenticationError.unavailable }
    func changePassword(userID: String, currentPassword: String, newPassword: String) async throws { throw AuthenticationError.unavailable }
    func refreshedUser(userID: String) async throws -> AuthenticatedUser { throw AuthenticationError.unavailable }
}
