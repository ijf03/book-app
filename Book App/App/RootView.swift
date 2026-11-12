import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router: AppRouter?

    private enum AppTab:
        Hashable
    {
        case home
        case library
        case search
        case progress
        case account
    }

    let bookRepository:
        any BookRepository

    let libraryStore:
        LibraryStore

    let readingSessionStore:
        ReadingSessionStore

    let authentication: AuthenticationState
    let sync: AccountSyncCoordinator?
    let reminders: ReadingRemindersViewModel

    @State
    private var selectedTab:
        AppTab = .home

    var body: some View {

        TabView(
            selection:
                $selectedTab
        ) {

            HomeView(
                store:
                    libraryStore,
                sessionStore:
                    readingSessionStore,
                onGoHome: {
                    selectedTab =
                        .home
                },
                onFindBooks: { selectedTab = .search },
                onShowProgress: { selectedTab = .progress }
            )
            .tag(
                AppTab.home
            )
            .tabItem {

                Label(
                    "Home",
                    systemImage:
                        "house"
                )
            }

            LibraryView(
                store: libraryStore,
                repository: bookRepository,
                onGoHome: { selectedTab = .home },
                onFindBooks: { selectedTab = .search }
            )
            .tag(
                AppTab.library
            )
            .tabItem {

                Label(
                    "Library",
                    systemImage:
                        "books.vertical"
                )
            }

            SearchView(
                repository:
                    bookRepository,
                libraryStore:
                    libraryStore,
                initialSearch: router?.searchRequest
            )
            .id(router?.searchRequest?.id)
            .tag(
                AppTab.search
            )
            .tabItem {

                Label(
                    "Search",
                    systemImage:
                        "magnifyingglass"
                )
            }

            ProgressDashboardView(
                libraryStore:
                    libraryStore,
                sessionStore:
                    readingSessionStore,
                reminders: reminders,
                repository: bookRepository
            )
            .tag(
                AppTab.progress
            )
            .tabItem {

                Label(
                    "Progress",
                    systemImage:
                        "chart.bar.fill"
                )
            }
            AccountView(authentication: authentication, sync: sync, profile: libraryStore.profile, library: libraryStore, sessions: readingSessionStore)
                .tag(AppTab.account)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .environment(\.bookCatalogue, bookRepository)
        .onChange(of: router?.searchRequest) { _, request in
            if request != nil { selectedTab = .search }
        }
        .task {
            await reminders.reconcile()
            await libraryStore.refreshSampleBooks(using: bookRepository)
        }
        .overlay(alignment: .top) {
            if libraryStore.isRefreshingSampleBooks {
                SwiftUI.ProgressView("Loading real books…")
                    .font(AppTypography.caption)
                    .padding(AppSpacing.sm)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(AppSpacing.md)
                    .accessibilityLabel("Refreshing sample books from Open Library")
            }
        }
        .alert("Some Books Couldn’t Load", isPresented: Binding(
            get: { libraryStore.sampleRefreshError != nil },
            set: { if !$0 { libraryStore.dismissSampleRefreshError() } }
        )) {
            Button("Try Again") {
                Task { await libraryStore.refreshSampleBooks(using: bookRepository) }
            }
            Button("Later", role: .cancel) { libraryStore.dismissSampleRefreshError() }
        } message: {
            Text(libraryStore.sampleRefreshError ?? "Please try again.")
        }
    }
}
