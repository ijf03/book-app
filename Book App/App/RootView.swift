import SwiftUI

struct RootView: View {

    let bookRepository: any BookRepository

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(
                        "Home",
                        systemImage: "house"
                    )
                }

            LibraryView()
                .tabItem {
                    Label(
                        "Library",
                        systemImage: "books.vertical"
                    )
                }

            SearchView(
                repository: bookRepository
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
