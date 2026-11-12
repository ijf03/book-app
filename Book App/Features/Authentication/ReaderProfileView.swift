import SwiftUI

struct ReaderProfileView: View {
    let store: ReaderProfileStore
    let isOnboarding: Bool
    let onFinish: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var username: String
    @State private var preferredName: String
    @State private var bio: String

    init(store: ReaderProfileStore, isOnboarding: Bool = false, onFinish: (() -> Void)? = nil) {
        self.store = store
        self.isOnboarding = isOnboarding
        self.onFinish = onFinish
        _username = State(initialValue: store.profile?.username ?? "")
        _preferredName = State(initialValue: store.profile?.preferredName ?? "")
        _bio = State(initialValue: store.profile?.bio ?? "")
    }

    private var draft: ReaderProfile {
        .draft(username: username, preferredName: preferredName, bio: bio)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isOnboarding {
                    Section {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Image("AppLogo").resizable().scaledToFit()
                                .frame(height: AppLayout.homeCoverWidth)
                                .accessibilityHidden(true)
                            Text("Welcome to Book App").font(AppTypography.largeTitle)
                            Text("What should I call you?").font(AppTypography.title)
                            Text("Choose a username to get started. Your preferred name and a little about your reading are optional. You can change these later in Account.")
                                .font(AppTypography.body)
                        }
                        .padding(.vertical, AppSpacing.sm)
                    }
                }
                Section("Your reader identity") {
                    TextField("Preferred name (optional)", text: $preferredName)
                        .textContentType(.givenName)
                    TextField("Username (required)", text: $username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.nickname)
                    TextField("A little about your reading (optional)", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                    Text("Your preferred name appears in greetings. Otherwise we use your username. Usernames are private profile labels, not unique handles or sign-in credentials.")
                        .font(AppTypography.caption)
                }
                if let error = store.error ?? (username.isEmpty ? nil : draft.validationError) {
                    Section { Label(error, systemImage: "exclamationmark.circle") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceSecondary)
            .tint(Color.appAccent)
            .navigationTitle(isOnboarding ? "Welcome" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(isOnboarding ? "Not now" : "Cancel") { finish() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isOnboarding ? "Start reading" : "Save") {
                        if store.save(draft, onlyIfMissing: isOnboarding) { finish() }
                    }
                        .disabled(draft.validationError != nil)
                }
            }
        }
    }
    private func finish() {
        if let onFinish { onFinish() } else { dismiss() }
    }
}

struct ReaderProfileCard: View {
    let store: ReaderProfileStore
    let email: String
    @State private var showsEditor = false
    private var profileName: some View {
        Text(store.profile?.displayName ?? String(localized: "Make yourself at home"))
            .font(AppTypography.title)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var profileUsername: some View {
        if let profile = store.profile {
            Text("@\(profile.username)")
                .font(AppTypography.body).foregroundStyle(Color.textSecondary)
        }
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(AppTypography.largeTitle).foregroundStyle(Color.appAccent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                                profileName
                                profileUsername
                            }
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                profileName
                                profileUsername
                            }
                        }
                        Text(email)
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Signed in as \(email)")
                            .accessibilityIdentifier("account.email")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let profile = store.profile {
                    if let bio = profile.bio { Text(bio).font(AppTypography.body) }
                } else {
                    Text("Choose a username and tell us what you like to be called.")
                        .foregroundStyle(Color.textSecondary)
                }
                Button { showsEditor = true } label: {
                    Label(store.profile == nil ? "Set up profile" : "Edit profile", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                }
                    .buttonStyle(.appSecondary)
                if let error = store.error {
                    Text(error).font(AppTypography.caption)
                    Button("Retry loading profile") { store.reload() }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showsEditor) { ReaderProfileView(store: store) }
    }
}
