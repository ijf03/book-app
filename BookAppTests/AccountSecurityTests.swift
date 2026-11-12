import Foundation
import Testing
@testable import Book_App

@MainActor struct AccountSecurityTests {
    @Test func validatesConfirmationPreservesPasswordsAndUpdatesEmailImmediately() async {
        let service = SecurityService()
        let auth = AuthenticationState(service: service)
        auth.start()
        let model = AccountSecurityViewModel(authentication: auth)
        model.currentPassword = " old "
        model.newPassword = " new "
        model.confirmation = "new"
        await model.submit(.password)
        #expect(service.passwordCalls == 0)
        model.confirmation = " new "
        await model.submit(.password)
        #expect(service.passwordCalls == 1 && service.oldPassword == " old " && service.newPassword == " new ")
        #expect(model.succeeded && model.currentPassword.isEmpty && model.newPassword.isEmpty)
        let email = AccountSecurityViewModel(authentication: auth)
        email.email = " new@example.com "
        email.currentPassword = " secret "
        await email.submit(.email)
        #expect(service.newEmail == "new@example.com" && service.oldPassword == " secret ")
        #expect(email.succeeded && email.currentPassword.isEmpty)
        #expect(auth.session == .signedIn(.init(id: "A", email: "new@example.com")))
    }

    @Test func offlineFailureKeepsSessionAndSameUIDRefreshDoesNotRecreateAccount() async {
        let service = SecurityService()
        let auth = AuthenticationState(service: service)
        var resets = 0
        auth.willChangeAccount = { _ in resets += 1 }
        auth.start()
        let model = AccountSecurityViewModel(authentication: auth)
        service.fails = true
        model.email = "new@example.com"; model.currentPassword = "secret"
        await model.submit(.email)
        #expect(!model.succeeded && auth.userID == "A")
        service.fails = false
        try? await auth.refreshUser()
        #expect(auth.session == .signedIn(.init(id: "A", email: "updated@example.com")))
        #expect(resets == 1)
    }

    @Test func emailChangeRequiresCurrentPasswordAndBackendFailureDoesNotChangeAddress() async {
        let service = SecurityService()
        let auth = AuthenticationState(service: service)
        auth.start()
        let model = AccountSecurityViewModel(authentication: auth)
        model.email = "new@example.com"
        await model.submit(.email)
        #expect(service.newEmail.isEmpty && !model.succeeded)
        model.currentPassword = "secret"
        service.fails = true
        await model.submit(.email)
        #expect(auth.session == .signedIn(.init(id: "A", email: "old@example.com")))
        #expect(!model.succeeded && model.currentPassword.isEmpty)
    }

    @Test func emailErrorsIdentifyTheCurrentPasswordOrNewAddress() async {
        let service = SecurityService()
        let auth = AuthenticationState(service: service)
        auth.start()
        let cases: [(AuthenticationError, String)] = [
            (.invalidCredentials, String(localized: "We couldn’t confirm your current password. Please re-enter it and try again.")),
            (.invalidEmail, String(localized: "Enter a valid new email address.")),
            (.emailInUse, String(localized: "Your new email address is already used by another account. Choose a different email address.")),
            (.offline, AuthenticationError.offline.message)
        ]
        for (failure, expected) in cases {
            service.failure = failure
            let model = AccountSecurityViewModel(authentication: auth)
            model.email = "new@example.com"
            model.currentPassword = "wrong"
            await model.submit(.email)
            #expect(model.message == expected)
            #expect(!model.succeeded && model.currentPassword.isEmpty)
            #expect(model.email == "new@example.com")
            #expect(auth.session == .signedIn(.init(id: "A", email: "old@example.com")))
        }
    }

    @Test func lateResultAfterSignOutCannotPublishSuccess() async {
        let service = SecurityService()
        let auth = AuthenticationState(service: service)
        auth.start()
        let model = AccountSecurityViewModel(authentication: auth)
        service.beforeReturn = { try? auth.signOut() }
        model.email = "new@example.com"; model.currentPassword = "secret"
        await model.submit(.email)
        #expect(!model.succeeded && model.message == nil && auth.userID == nil)
    }
}

@MainActor private final class SecurityService: AuthenticationService {
    var passwordCalls = 0
    var oldPassword = ""
    var newPassword = ""
    var newEmail = ""
    var fails = false
    var failure: AuthenticationError?
    var beforeReturn: (() -> Void)?
    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation {
        onChange(.init(id: "A", email: "old@example.com"))
        return SecurityObservation()
    }
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signOut() throws {}
    func changeEmail(userID: String, email: String, currentPassword: String) async throws {
        if let failure { throw failure }
        if fails { throw AuthenticationError.offline }
        oldPassword = currentPassword
        newEmail = email
        await Task.yield()
        beforeReturn?()
    }
    func changePassword(userID: String, currentPassword: String, newPassword: String) async throws {
        passwordCalls += 1; oldPassword = currentPassword; self.newPassword = newPassword
    }
    func refreshedUser(userID: String) async throws -> AuthenticatedUser {
        .init(id: userID, email: "updated@example.com")
    }
}
@MainActor private final class SecurityObservation: AuthenticationObservation { func cancel() {} }
