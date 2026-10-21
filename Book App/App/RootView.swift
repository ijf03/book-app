import SwiftUI

struct RootView: View {

    private enum AppTab:
        Hashable
    {
        case home
        case library
        case search
        case progress
    }

    let bookRepository:
        any BookRepository

    let libraryStore:
        LibraryStore

    let readingSessionStore:
        ReadingSessionStore

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
                }
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
                store:
                    libraryStore,
                onGoHome: {
                    selectedTab =
                        .home
                }
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
                    libraryStore
            )
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
                    readingSessionStore
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
        }
        .task {
            await ReadingRemindersViewModel().reconcile()
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
