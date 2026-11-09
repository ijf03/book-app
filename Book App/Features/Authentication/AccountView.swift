import SwiftUI

struct AccountView: View {
    @State private var model: AccountViewModel
    let sync: AccountSyncCoordinator?

    init(authentication: AuthenticationState, sync: AccountSyncCoordinator? = nil) {
        self.sync = sync
        _model = State(initialValue: AccountViewModel(authentication: authentication, sync: sync))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Signed in as").font(AppTypography.headline)
                            Text(model.email).font(AppTypography.body)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("account.email")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Your reading data is saved locally and syncs to your account when connected. A new device needs internet access to download your library.")
                        .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                    if let sync { AccountSyncSection(coordinator: sync) }
                    if model.isWaitingToSignOut {
                        SwiftUI.ProgressView("Syncing before signing out…")
                            .accessibilityIdentifier("account.syncBeforeSignOut")
                        Button("Cancel sign-out", action: model.cancelSignOut)
                            .buttonStyle(.appSecondary)
                    }
                    Button("Sign out", action: model.requestSignOut)
                        .buttonStyle(.appSecondary)
                        .disabled(model.isWaitingToSignOut)
                        .accessibilityIdentifier("account.signOut")
                    if let error = model.errorMessage {
                        Text(error).font(AppTypography.body).foregroundStyle(Color.danger)
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: AppLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("Account")
            .alert("Sync before signing out?", isPresented: $model.showsSignOutWarning) {
                Button("Sync and sign out", action: model.syncAndSignOut)
                Button("Sign out anyway", role: .destructive, action: model.signOut)
                Button("Cancel", role: .cancel, action: model.cancelSignOut)
            } message: {
                Text("Some changes or saved conflicts aren’t confirmed in the cloud. They’ll stay on this device for this account, but won’t be available on other devices until resolved and synced.")
            }
            .onChange(of: sync?.phase) { _, _ in model.syncStatusChanged() }
            .onChange(of: sync?.local.pendingCount) { _, _ in model.syncStatusChanged() }
            .onDisappear { model.cancelSignOut() }
        }
    }
}
