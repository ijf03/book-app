import Foundation
import Observation

@MainActor
@Observable
final class AccountViewModel {
    private(set) var errorMessage: String?
    let authentication: AuthenticationState

    init(authentication: AuthenticationState) { self.authentication = authentication }

    var email: String {
        guard case .signedIn(let user) = authentication.session else { return "" }
        return user.email
    }

    func signOut() {
        do { try authentication.signOut(); errorMessage = nil }
        catch { errorMessage = (error as? AuthenticationError ?? .unknown).message }
    }
}
