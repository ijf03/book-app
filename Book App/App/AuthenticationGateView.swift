import SwiftUI

struct AuthenticationGateView: View {
    let container: AppContainer

    var body: some View {
        Group {
            switch container.authentication.session {
            case .checkingSession:
                SwiftUI.ProgressView("Checking your session…")
            case .signedOut:
                AuthenticationView(service: container.authenticationService)
            case .signedIn:
                if let account = container.account, container.storageState == .ready {
                    RootView(
                        bookRepository: container.bookRepository,
                        libraryStore: account.libraryStore,
                        readingSessionStore: account.readingSessionStore,
                        authentication: container.authentication
                    )
                    .environment(account.router)
                    .environment(account.readingSessionStore)
                    .environment(account.bookContentStore)
                    .id(account.id)
                } else {
                    AccountStorageChoiceView(container: container)
                }
            }
        }
        .tint(Color.appAccent)
    }
}

private struct AccountStorageChoiceView: View {
    let container: AppContainer
    @State private var accountModel: AccountViewModel

    init(container: AppContainer) {
        self.container = container
        _accountModel = State(initialValue: AccountViewModel(authentication: container.authentication))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(accountModel.email).font(AppTypography.headline)
                if container.storageState == .needsLegacyChoice {
                    Text("Keep your existing reading data?").font(AppTypography.largeTitle)
                    Text("This device has reading data from before accounts were added. It has no verified owner. Import it only if it is yours. A separate copy will be saved for this account; the original will stay untouched.")
                        .font(AppTypography.body)
                    Button("Import my existing data") { container.chooseLegacyImport(true) }
                        .buttonStyle(.appPrimary).accessibilityIdentifier("legacy.import")
                    Button("Start with an empty library") { container.chooseLegacyImport(false) }
                        .buttonStyle(.appSecondary).accessibilityIdentifier("legacy.empty")
                } else {
                    Text("Couldn’t open your local data").font(AppTypography.largeTitle)
                    Text("Your saved files have been preserved. Try again, or sign out to use another account.")
                        .font(AppTypography.body)
                    Button("Try again", action: container.retryStorage)
                        .buttonStyle(.appPrimary).accessibilityIdentifier("storage.retry")
                }
                Button("Sign out", action: accountModel.signOut)
                    .buttonStyle(.appSecondary).accessibilityIdentifier("storage.signOut")
                if let error = accountModel.errorMessage {
                    Text(error).foregroundStyle(Color.danger)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.surfaceSecondary)
    }
}
