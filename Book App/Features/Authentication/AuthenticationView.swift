import SwiftUI

struct AuthenticationView: View {
    @State private var model: AuthenticationViewModel

    init(service: any AuthenticationService) {
        _model = State(initialValue: AuthenticationViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text(model.title).font(AppTypography.largeTitle)
                    Text("Your next chapter starts here.")
                        .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                    AuthenticationFields(model: model)
                    AuthenticationFeedback(submission: model.submission)
                    AuthenticationLinks(model: model)
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: AppLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.surfaceSecondary)
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await model.submit() }
                } label: {
                    HStack {
                        if model.isLoading { SwiftUI.ProgressView().tint(Color.surface) }
                        Text(model.actionTitle)
                    }
                }
                .buttonStyle(.appPrimary)
                .disabled(model.isLoading)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("auth.submit")
                .padding(AppSpacing.md)
                .frame(maxWidth: AppLayout.readableWidth)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceSecondary)
            }
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
        .textFieldStyle(.roundedBorder)
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if model.mode == .login {
                Button("Forgot password?") { model.changeMode(.reset) }
                    .accessibilityIdentifier("auth.forgotPassword")
                Button("Create an account") { model.changeMode(.signUp) }
                    .accessibilityIdentifier("auth.createAccount")
            } else {
                Button("Back to log in") { model.changeMode(.login) }
                    .accessibilityIdentifier("auth.backToLogin")
            }
        }
        .buttonStyle(.appSecondary)
        .disabled(model.isLoading)
    }
}
