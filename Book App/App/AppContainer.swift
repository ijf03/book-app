import Foundation

@MainActor
final class AppContainer {

    let router: AppRouter

    let bookRepository:
        any BookRepository

    let libraryStore:
        LibraryStore

    init() {

        self.router =
            AppRouter()

        // MARK: - Local Persistence

        let localDataSource =
            LocalLibraryDataSource()

        var initialBooks =
            Book.mockBooks

        do {

            if let savedBooks =
                try localDataSource
                    .loadBooks()
            {
                initialBooks =
                    savedBooks

                print(
                    "✅ App launched with \(savedBooks.count) saved books."
                )

            } else {

                try localDataSource
                    .saveBooks(
                        initialBooks
                    )

                print(
                    "🌱 First launch: seeded library with \(initialBooks.count) mock books."
                )
            }

        } catch {

            print(
                "❌ Failed to initialise local library:"
            )

            print(error)

            print(
                "⚠️ Using mock books for this launch."
            )
        }

        self.libraryStore =
            LibraryStore(
                books:
                    initialBooks,
                localDataSource:
                    localDataSource
            )

        // MARK: - Open Library

        let openLibraryDataSource =
            OpenLibraryRemoteDataSource()

        self.bookRepository =
            DefaultBookRepository(
                remoteDataSource:
                    openLibraryDataSource
            )
    }
}
