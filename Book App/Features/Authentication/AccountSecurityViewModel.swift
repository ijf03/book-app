import Foundation
import Observation

@MainActor @Observable
final class AccountSecurityViewModel {
    enum Action: String, Identifiable { case email, password; var id: Self { self } }
    var email = ""
    var currentPassword = ""
    var newPassword = ""
    var confirmation = ""
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var succeeded = false
    let authentication: AuthenticationState
    private let generation: UUID

    init(authentication: AuthenticationState) {
        self.authentication = authentication
        generation = authentication.generation
    }

    func submit(_ action: Action) async {
        guard !isLoading, !succeeded, generation == authentication.generation else { return }
        message = nil
        guard !currentPassword.isEmpty else { message = String(localized: "Enter your current password."); return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if action == .email && trimmedEmail.isEmpty { message = String(localized: "Enter your new email address."); return }
        if action == .password {
            guard !newPassword.isEmpty else { message = String(localized: "Enter your new password."); return }
            guard newPassword == confirmation else { message = String(localized: "Your new passwords don’t match."); return }
        }
        isLoading = true
        defer { isLoading = false; clearPasswords() }
        do {
            if action == .email {
                try await authentication.changeEmail(trimmedEmail, password: currentPassword)
            } else {
                try await authentication.changePassword(current: currentPassword, new: newPassword)
            }
            guard !Task.isCancelled, generation == authentication.generation else { return }
            succeeded = true
            message = action == .email
                ? String(localized: "Your email has been changed. Use the new email next time you sign in.")
                : String(localized: "Your password has been changed. Use the new password next time you sign in.")
        } catch {
            guard !Task.isCancelled, generation == authentication.generation else { return }
            // This form confirms the signed-in account with its current password;
            // the entered email is a replacement address, not a login credential.
            let failure = error as? AuthenticationError ?? .unknown
            switch failure {
            case .invalidCredentials:
                message = String(localized: "We couldn’t confirm your current password. Please re-enter it and try again.")
            case .invalidEmail where action == .email:
                message = String(localized: "Enter a valid new email address.")
            case .emailInUse where action == .email:
                message = String(localized: "Your new email address is already used by another account. Choose a different email address.")
            default:
                message = failure.message
            }
        }
    }

    func clearPasswords() { currentPassword = ""; newPassword = ""; confirmation = "" }
}
