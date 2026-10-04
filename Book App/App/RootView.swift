import SwiftUI

struct RootView: View {

    let bookRepository: any BookRepository
    let libraryStore: LibraryStore

    var body: some View {
        TabView {

            HomeView()
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

            ProgressDashboardView()
                .tabItem {
                    Label(
                        "Progress",
                        systemImage: "chart.bar"
                    )
                }
        }
    }
}
