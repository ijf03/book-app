import SwiftUI

struct AccountSecurityView: View {
    let action: AccountSecurityViewModel.Action
    @State private var model: AccountSecurityViewModel
    @State private var request = 0
    @Environment(\.dismiss) private var dismiss
    @FocusState private var field: Field?
    private enum Field { case email, current, new, confirmation }

    init(action: AccountSecurityViewModel.Action, authentication: AuthenticationState) {
        self.action = action
        _model = State(initialValue: AccountSecurityViewModel(authentication: authentication))
    }

    var body: some View {
        NavigationStack {
            Form {
                if !model.succeeded {
                    Section {
                        if action == .email {
                            TextField("New email address", text: $model.email)
                                .keyboardType(.emailAddress).textContentType(.emailAddress)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($field, equals: .email).submitLabel(.next)
                                .onSubmit { field = .current }
                        }
                        SecureField("Current password", text: $model.currentPassword)
                            .textContentType(.password).focused($field, equals: .current)
                            .submitLabel(action == .password ? .next : .done)
                            .onSubmit { if action == .password { field = .new } else { submit() } }
                        if action == .password {
                            SecureField("New password", text: $model.newPassword)
                                .textContentType(.newPassword).focused($field, equals: .new)
                                .submitLabel(.next).onSubmit { field = .confirmation }
                            SecureField("Confirm new password", text: $model.confirmation)
                                .textContentType(.newPassword).focused($field, equals: .confirmation)
                                .submitLabel(.done).onSubmit { submit() }
                        }
                    }
                    .disabled(model.isLoading)
                    Section {
                        Text("Confirm your current password to protect your account. Passwords are never saved on this device.")
                        if action == .email {
                            Text("Your email address will change after your current password is confirmed.")
                        } else {
                            Text("Your new password must meet the account’s password requirements.")
                        }
                    }.font(AppTypography.caption)
                    Button(action == .email ? "Change email" : "Change password", action: submit)
                        .disabled(model.isLoading)
                }
                if model.isLoading { SwiftUI.ProgressView("Updating account…") }
                if let message = model.message {
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(model.succeeded ? Color.textPrimary : Color.danger)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceSecondary)
            .tint(Color.appAccent)
            .navigationTitle(action == .email ? "Change email" : "Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.succeeded ? "Done" : "Cancel") { dismiss() }
                }
            }
            .task(id: request) {
                guard request > 0 else { return }
                await model.submit(action)
            }
            .onDisappear { model.clearPasswords() }
        }
    }

    private func submit() {
        guard !model.isLoading else { return }
        field = nil
        request += 1
    }
}

struct AccountSecuritySection: View {
    let authentication: AuthenticationState
    @State private var action: AccountSecurityViewModel.Action?

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("Account security", systemImage: "lock.shield").font(AppTypography.title).accessibilityAddTraits(.isHeader)
                Button("Change password") { action = .password }.buttonStyle(.appSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $action) { AccountSecurityView(action: $0, authentication: authentication) }
    }
}
