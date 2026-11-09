import SwiftUI

struct AccountView: View {
    @State private var model: AccountViewModel

    init(authentication: AuthenticationState) {
        _model = State(initialValue: AccountViewModel(authentication: authentication))
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
                    Text("Your books and reading activity are saved on this device for this account. Cloud sync is not available.")
                        .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                    Button("Sign out", action: model.signOut)
                        .buttonStyle(.appSecondary)
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
        }
    }
}
