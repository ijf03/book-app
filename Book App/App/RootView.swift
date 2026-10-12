import SwiftUI

struct RootView: View {

    let bookRepository: any BookRepository
    let libraryStore: LibraryStore
    let readingSessionStore: ReadingSessionStore

    var body: some View {
        TabView {

            HomeView(
                store:
                    libraryStore,
                sessionStore:
                    readingSessionStore
            )
                .tabItem {
                    Label(
                        "Home",
                        systemImage: "house"
                    )
                }

            LibraryView(
                store: libraryStore
            )
            .tabItem {
                Label(
                    "Library",
                    systemImage: "books.vertical"
                )
            }

            SearchView(
                repository: bookRepository,
                libraryStore: libraryStore
            )
            .tabItem {
                Label(
                    "Search",
                    systemImage: "magnifyingglass"
                )
            }

            ProgressDashboardView(
                libraryStore:
                    libraryStore,
                sessionStore:
                    readingSessionStore
            )
            .tabItem {
                Label(
                    "Progress",
                    systemImage:
                        "chart.bar.fill"
                )
            }
        }
    }
}
