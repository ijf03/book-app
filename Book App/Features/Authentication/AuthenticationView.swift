import SwiftUI
import Accessibility

struct AuthenticationView: View {
    @State private var model: AuthenticationViewModel
    @State private var contentHeight: CGFloat = 0

    init(service: any AuthenticationService, initialMode: AuthenticationViewModel.Mode = .login) {
        let model = AuthenticationViewModel(service: service)
        model.changeMode(initialMode)
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    VStack(spacing: AppSpacing.sm) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.height < 650 ? AppLayout.minimumTapTarget : AppLayout.authenticationLogoSize, height: geometry.size.height < 650 ? AppLayout.minimumTapTarget : AppLayout.authenticationLogoSize)
                            .accessibilityHidden(true)
                        Text("BOOK TRACKER")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.appAccent)
                        Text(model.mode == .login ? "Welcome back" : "Create your account")
                            .font(AppTypography.largeTitle)
                            .multilineTextAlignment(.center)
                        if geometry.size.height >= 650 {
                        Text(model.mode == .login ? "Pick up where you left off." : "A home for your books, notes and reading moments.")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                        }
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(model.title).font(AppTypography.title).accessibilityAddTraits(.isHeader)
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
                .padding(AppSpacing.md)
                .frame(maxWidth: AppLayout.authenticationWidth)
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { content in
                        Color.clear.preference(key: AuthenticationHeightKey.self, value: content.size.height)
                    }
                }
            }
            .onPreferenceChange(AuthenticationHeightKey.self) { contentHeight = $0 }
            .scrollDisabled(contentHeight <= geometry.size.height)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .background(Color.surfaceSecondary)
            }
        }
        .tint(Color.appAccent)
    }
}

private struct AuthenticationHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct AuthenticationFields: View {
    @Bindable var model: AuthenticationViewModel
    @FocusState private var focus: AuthenticationViewModel.Field?
    @State private var showsPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            TextField("Email address", text: $model.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { focus = .password }
                .accessibilityIdentifier("auth.email")
                .accessibilityHint(model.validation(.email) ?? "")
            FieldValidation(message: model.validation(.email))
            VStack(alignment: .leading, spacing: AppSpacing.md) {
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
                .accessibilityHint(model.validation(.password) ?? "")
                .padding(.trailing, AppLayout.minimumTapTarget)
                .overlay(alignment: .trailing) {
                    Button { showsPassword.toggle() } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .frame(width: AppLayout.minimumTapTarget, height: AppLayout.minimumTapTarget)
                    }
                    .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
                    .accessibilityIdentifier("auth.showPassword")
                }
                FieldValidation(message: model.validation(.password))
            }
            if model.mode == .signUp {
                SecureField("Confirm password", text: $model.confirmation)
                    .textContentType(.newPassword)
                    .focused($focus, equals: .confirmation)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.submit() } }
                    .accessibilityIdentifier("auth.confirmation")
                    .accessibilityHint(model.validation(.confirmation) ?? "")
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
                .onChange(of: message, initial: true) { _, message in
                    AccessibilityNotification.Announcement(message).post()
                }
        case .idle, .loading: EmptyView()
        }
    }
}

private struct AuthenticationLinks: View {
    let model: AuthenticationViewModel
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            if model.mode == .login {
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
    func signOut() throws {}
}

#Preview("Login") {
    AuthenticationView(service: AuthenticationPreviewService())
}
#Preview("Sign up") {
    AuthenticationView(service: AuthenticationPreviewService(), initialMode: .signUp)
}
#endif
