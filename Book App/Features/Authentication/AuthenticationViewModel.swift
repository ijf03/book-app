import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    enum Mode: Equatable { case login, signUp }
    enum Submission: Equatable { case idle, loading, failed(String) }
    enum Field: Hashable { case email, password, confirmation }

    var email = ""
    var password = ""
    var confirmation = ""
    private(set) var mode: Mode = .login
    private(set) var submission: Submission = .idle
    private(set) var visited: Set<Field> = []
    private let service: any AuthenticationService

    init(service: any AuthenticationService) { self.service = service }
    var isLoading: Bool { submission == .loading }
    var title: String {
        switch mode {
        case .login: String(localized: "Log in")
        case .signUp: String(localized: "Create account")
        }
    }
    var actionTitle: String { title }

    func changeMode(_ mode: Mode) {
        guard !isLoading else { return }
        self.mode = mode
        password = ""; confirmation = ""; visited = []; submission = .idle
    }

    func didLeave(_ field: Field?) {
        if let field { visited.insert(field) }
    }

    func validation(_ field: Field) -> String? {
        guard visited.contains(field) else { return nil }
        switch field {
        case .email:
            let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { return String(localized: "Enter your email address.") }
            if !value.contains("@") { return AuthenticationError.invalidEmail.message }
        case .password:
            if password.isEmpty { return String(localized: "Enter your password.") }
        case .confirmation:
            if mode == .signUp && confirmation != password { return String(localized: "Your passwords don’t match.") }
            if mode == .signUp && confirmation.isEmpty { return String(localized: "Confirm your password.") }
        }
        return nil
    }

    func submit() async {
        guard !isLoading else { return }
        visited = [.email, .password, .confirmation]
        guard [Field.email, .password, .confirmation].allSatisfy({ validation($0) == nil }) else { return }
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        submission = .loading
        do {
            switch mode {
            case .login: try await service.signIn(email: email, password: password)
            case .signUp: try await service.signUp(email: email, password: password)
            }
            password = ""; confirmation = ""
            submission = .idle
        } catch {
            submission = .failed((error as? AuthenticationError ?? .unknown).message)
        }
    }
}
