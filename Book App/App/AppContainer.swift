import Foundation

@MainActor
final class AppContainer {

    let router:
        AppRouter

    let bookRepository:
        any BookRepository

    let libraryStore:
        LibraryStore

    let readingSessionStore:
        ReadingSessionStore

    init() {

        self.router =
            AppRouter()

        // MARK: - Library Persistence

        let localLibraryDataSource =
            LocalLibraryDataSource()

        var initialBooks =
            Book.mockBooks

        do {
            if let savedBooks =
                try localLibraryDataSource
                    .loadBooks()
            {
                initialBooks =
                    savedBooks

                print(
                    "✅ App launched with \(savedBooks.count) saved books."
                )

            } else {
                try localLibraryDataSource
                    .saveBooks(
                        initialBooks
                    )

                print(
                    "🌱 First launch: seeded library with \(initialBooks.count) mock books."
                )
            }

        } catch {
            print(
                "❌ Failed to initialise local library:",
                error
            )
        }

        self.libraryStore =
            LibraryStore(
                books:
                    initialBooks,
                localDataSource:
                    localLibraryDataSource
            )

        // MARK: - Reading Sessions

        let localSessionDataSource =
            LocalReadingSessionDataSource()

        var initialSessions:
            [ReadingSession] = []

        do {
            initialSessions =
                try localSessionDataSource
                    .loadSessions()

        } catch {
            print(
                "❌ Failed to initialise reading sessions:",
                error
            )
        }

        self.readingSessionStore =
            ReadingSessionStore(
                sessions:
                    initialSessions,
                localDataSource:
                    localSessionDataSource
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
