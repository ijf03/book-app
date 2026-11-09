import Foundation

@MainActor
final class AccountSession {
    let id = UUID()
    let scope: AccountStorageScope
    let router = AppRouter()
    let libraryStore: LibraryStore
    let readingSessionStore: ReadingSessionStore
    let bookContentStore: BookContentStore
    let reminders: ReadingRemindersViewModel
    let sync: AccountSyncCoordinator?
    private var reminderTask: Task<Void, Never>?

    init(scope: AccountStorageScope, userID: String? = nil, cloudService: (any CloudSyncService)? = nil) throws {
        self.scope = scope
        if let userID, let cloudService {
            let local = try LocalSyncRepository(userID: userID, scope: scope)
            scope.syncRepository = local
            sync = AccountSyncCoordinator(userID: userID, local: local, service: cloudService)
        } else { sync = nil }
        let library = LocalLibraryDataSource(scope: scope)
        let sessions = LocalReadingSessionDataSource(scope: scope)
        let content = LocalBookContentDataSource(scope: scope)
        let books = try library.loadBooks() ?? []
        let savedSessions = try sessions.loadSessions()
        let savedContent = try content.loadContent()
        libraryStore = LibraryStore(books: books, localDataSource: library)
        readingSessionStore = ReadingSessionStore(sessions: savedSessions, localDataSource: sessions)
        bookContentStore = BookContentStore(notes: savedContent.notes, reviews: savedContent.reviews, localDataSource: content)
        reminders = ReadingRemindersViewModel(repository: .init(fileName: "reading-reminders.json", scope: scope))
        sync?.local.onRemoteChange = { [weak self] in self?.reloadDownloadedData() }
    }

    private func reloadDownloadedData() {
        guard scope.isActive else { return }
        libraryStore.reloadFromLocalSync()
        readingSessionStore.reloadFromLocalSync()
        bookContentStore.reloadFromLocalSync()
        scope.publishCloudChange()
        reminderTask?.cancel()
        reminderTask = Task { [weak self] in
            guard let self else { return }
            await self.reminders.reconcile()
        }
    }

    func invalidate() {
        sync?.stop()
        reminderTask?.cancel()
        scope.invalidate()
        libraryStore.clearAccountMemory()
        readingSessionStore.clearAccountMemory()
        bookContentStore.clearAccountMemory()
        LocalReadingNotificationService(scope: scope).cancel()
    }
}
