import Foundation

@MainActor
final class AppContainer {

    let router: AppRouter
    let bookRepository: any BookRepository
    let libraryStore: LibraryStore

    init() {
        self.router = AppRouter()

        self.libraryStore = LibraryStore(
            books: Book.mockBooks
        )

        let openLibraryDataSource =
            OpenLibraryRemoteDataSource()

        self.bookRepository =
            DefaultBookRepository(
                remoteDataSource:
                    openLibraryDataSource
            )
    }
}
