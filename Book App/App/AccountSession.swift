import Foundation

@MainActor
final class AccountSession {
    let id = UUID()
    let scope: AccountStorageScope
    let router = AppRouter()
    let libraryStore: LibraryStore
    let readingSessionStore: ReadingSessionStore
    let bookContentStore: BookContentStore

    init(scope: AccountStorageScope) throws {
        self.scope = scope
        let library = LocalLibraryDataSource(scope: scope)
        let sessions = LocalReadingSessionDataSource(scope: scope)
        let content = LocalBookContentDataSource(scope: scope)
        // Load everything before exposing any account data to the view tree.
        let books = try library.loadBooks() ?? []
        let savedSessions = try sessions.loadSessions()
        let savedContent = try content.loadContent()
        libraryStore = LibraryStore(books: books, localDataSource: library)
        readingSessionStore = ReadingSessionStore(sessions: savedSessions, localDataSource: sessions)
        bookContentStore = BookContentStore(notes: savedContent.notes, reviews: savedContent.reviews, localDataSource: content)
    }

    func invalidate() {
        scope.invalidate()
        libraryStore.clearAccountMemory()
        readingSessionStore.clearAccountMemory()
        bookContentStore.clearAccountMemory()
        LocalReadingNotificationService(scope: scope).cancel()
    }
}
