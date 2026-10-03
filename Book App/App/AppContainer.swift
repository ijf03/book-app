import Foundation

@MainActor
final class AppContainer {

    let router: AppRouter
    let bookRepository: any BookRepository

    init() {
        self.router = AppRouter()

        let openLibraryDataSource =
            OpenLibraryRemoteDataSource()

        self.bookRepository =
            DefaultBookRepository(
                remoteDataSource:
                    openLibraryDataSource
            )
    }
}
