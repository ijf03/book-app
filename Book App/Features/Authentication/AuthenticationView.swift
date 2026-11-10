import SwiftUI

struct AuthenticationView: View {
    @State private var model: AuthenticationViewModel

    init(service: any AuthenticationService, initialMode: AuthenticationViewModel.Mode = .login) {
        let model = AuthenticationViewModel(service: service)
        model.changeMode(initialMode)
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.sm) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: AppLayout.authenticationLogoSize, height: AppLayout.authenticationLogoSize)
                            .accessibilityHidden(true)
                        Text("BOOK TRACKER")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.appAccent)
                        Text(model.mode == .login ? "Welcome back" : model.mode == .signUp ? "Your next chapter starts here" : "Forgot your password?")
                            .font(AppTypography.largeTitle)
                            .multilineTextAlignment(.center)
                        Text(model.mode == .login ? "Pick up where you left off." : model.mode == .signUp ? "A home for your books, notes and reading moments." : "We’ll help you get back to your books.")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            Text(model.title).font(AppTypography.title)
                            AuthenticationFields(model: model)
                            AuthenticationFeedback(submission: model.submission)
                            Button {
                                Task { await model.submit() }
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    if model.isLoading { SwiftUI.ProgressView().tint(Color.surface) }
                                    Text(model.actionTitle)
                                    Image(systemName: "arrow.right").accessibilityHidden(true)
                                }
                                .padding(.vertical, AppSpacing.sm)
                            }
                            .buttonStyle(.appPrimary)
                            .disabled(model.isLoading)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityIdentifier("auth.submit")
                            AuthenticationLinks(model: model)
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: AppLayout.authenticationWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.surfaceSecondary)
        }
        .tint(Color.appAccent)
    }
}

private struct AuthenticationFields: View {
    @Bindable var model: AuthenticationViewModel
    @FocusState private var focus: AuthenticationViewModel.Field?
    @State private var showsPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Email").font(AppTypography.headline)
            TextField("Email address", text: $model.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(model.mode == .reset ? .send : .next)
                .onSubmit {
                    if model.mode == .reset { Task { await model.submit() } }
                    else { focus = .password }
                }
                .accessibilityIdentifier("auth.email")
            FieldValidation(message: model.validation(.email))
            if model.mode != .reset {
                Text("Password").font(AppTypography.headline)
                Group {
                    if showsPassword {
                        TextField("Password", text: $model.password)
                    } else {
                        SecureField("Password", text: $model.password)
                    }
                }
                .textContentType(model.mode == .signUp ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .password)
                .submitLabel(model.mode == .signUp ? .next : .go)
                .onSubmit {
                    if model.mode == .signUp { focus = .confirmation }
                    else { Task { await model.submit() } }
                }
                .accessibilityIdentifier("auth.password")
                Button(showsPassword ? "Hide password" : "Show password") { showsPassword.toggle() }
                    .frame(minHeight: AppLayout.minimumTapTarget)
                    .accessibilityIdentifier("auth.showPassword")
                FieldValidation(message: model.validation(.password))
            }
            if model.mode == .signUp {
                Text("Password requirements are checked securely when you create your account.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                Text("Confirm password").font(AppTypography.headline)
                SecureField("Confirm password", text: $model.confirmation)
                    .textContentType(.newPassword)
                    .focused($focus, equals: .confirmation)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.submit() } }
                    .accessibilityIdentifier("auth.confirmation")
                FieldValidation(message: model.validation(.confirmation))
            }
        }
        .font(AppTypography.body)
        .textFieldStyle(AuthenticationFieldStyle())
        .disabled(model.isLoading)
        .onChange(of: focus) { previous, _ in model.didLeave(previous) }
        .onChange(of: model.mode) { _, _ in showsPassword = false; focus = .email }
    }
}

private struct FieldValidation: View {
    let message: String?
    var body: some View {
        if let message {
            Text(message).font(AppTypography.caption).foregroundStyle(Color.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AuthenticationFeedback: View {
    let submission: AuthenticationViewModel.Submission
    var body: some View {
        switch submission {
        case .failed(let message):
            Text(message).font(AppTypography.body).foregroundStyle(Color.danger)
                .accessibilityIdentifier("auth.error")
        case .resetSent:
            Text("If an account uses this email, you’ll receive a password reset link. Check your inbox and spam folder.")
                .font(AppTypography.body).accessibilityIdentifier("auth.resetSent")
        case .idle, .loading: EmptyView()
        }
    }
}

private struct AuthenticationLinks: View {
    let model: AuthenticationViewModel
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            if model.mode == .login {
                Button("Forgot password?") { model.changeMode(.reset) }
                    .frame(minHeight: AppLayout.minimumTapTarget)
                    .accessibilityIdentifier("auth.forgotPassword")
                Divider()
                Text("New to Book Tracker?")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                Button("Create an account") { model.changeMode(.signUp) }
                    .buttonStyle(.appSecondary)
                    .accessibilityIdentifier("auth.createAccount")
            } else {
                Divider()
                Button("Back to log in") { model.changeMode(.login) }
                    .frame(minHeight: AppLayout.minimumTapTarget)
                    .accessibilityIdentifier("auth.backToLogin")
            }
        }
        .font(AppTypography.headline)
        .frame(maxWidth: .infinity)
        .disabled(model.isLoading)
    }
}

private struct AuthenticationFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppSpacing.md)
            .frame(minHeight: AppLayout.minimumTapTarget)
            .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(Color.border, lineWidth: 1)
            }
    }
}

#if DEBUG
@MainActor private final class AuthenticationPreviewService: AuthenticationService, AuthenticationObservation {
    func observeSession(_ onChange: @escaping @MainActor (AuthenticatedUser?) -> Void) -> any AuthenticationObservation { self }
    func cancel() {}
    func signUp(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func resetPassword(email: String) async throws {}
    func signOut() throws {}
}

#Preview("Login") {
    AuthenticationView(service: AuthenticationPreviewService())
}
#Preview("Sign up") {
    AuthenticationView(service: AuthenticationPreviewService(), initialMode: .signUp)
}
#endif
