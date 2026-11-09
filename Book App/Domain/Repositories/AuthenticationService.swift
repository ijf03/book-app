import Foundation

@MainActor
protocol AuthenticationService: AnyObject {
    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func resetPassword(email: String) async throws
    func signOut() throws
}

@MainActor
protocol AuthenticationObservation: AnyObject {
    func cancel()
}
