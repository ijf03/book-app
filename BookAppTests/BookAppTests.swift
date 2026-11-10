import Foundation
import Testing
import UserNotifications
@testable import Book_App

@MainActor
struct BookAppTests {
    private func makeStorage() throws -> (URL, LocalLibraryDataSource) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (root, LocalLibraryDataSource(fileManager: IsolatedFileManager(root: root)))
    }

    @Test func savedAPIBookSurvivesReloadAndRejectsDuplicate() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let book = BookFactory.makeBook(from: apiResult, status: .toRead, format: .ebook)
        let store = LibraryStore(books: [], localDataSource: dataSource)
        #expect(store.addBook(book))
        #expect(!store.addBook(book))
        #expect(try dataSource.loadBooks() == [book])
        #expect(store.books.count == 1)
    }

    @Test func failedSaveRollsBackAndCanBeRetried() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let blocker = root.appendingPathComponent("BookApp")
        try Data("not a directory".utf8).write(to: blocker)
        let book = BookFactory.makeBook(from: apiResult, status: .reading, format: .physical)
        let store = LibraryStore(books: [], localDataSource: dataSource)
        #expect(!store.addBook(book))
        #expect(store.books.isEmpty)
        #expect(store.persistenceError != nil)
        try FileManager.default.removeItem(at: blocker)
        #expect(store.addBook(book))
        #expect(store.persistenceError == nil)
        #expect(try dataSource.loadBooks() == [book])
    }

    @Test func legacyJSONWithoutAPIIdentifierStillDecodes() throws {
        let book = Book.mockFourthWing
        let encoded = try JSONEncoder().encode(book)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "sourceBookID")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Book.self, from: legacyData)
        #expect(decoded == book)
        #expect(decoded.sourceBookID == nil)
    }

    @Test func refreshPreservesReaderDataAndIsIdempotent() async throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Book.mockFourthWing
        var personalBook = BookFactory.makeBook(from: apiResult, status: .toRead, format: .ebook)
        personalBook = Book(id: "personal-book", title: personalBook.title, authors: personalBook.authors, description: nil, coverURL: nil, pageCount: 400, status: .toRead, format: .ebook)
        let store = LibraryStore(books: [original, personalBook], localDataSource: dataSource)
        let repository = StubRepository(result: apiResult)
        await store.refreshSampleBooks(using: repository)
        let refreshed = try #require(store.book(id: original.id))
        #expect(refreshed.id == original.id)
        #expect(refreshed.sourceBookID == apiResult.id)
        #expect(refreshed.coverURL == apiResult.coverURL)
        #expect(refreshed.status == original.status)
        #expect(refreshed.format == original.format)
        #expect(refreshed.progress == original.progress)
        #expect(store.book(id: "personal-book") == personalBook)
        #expect(store.contains(bookID: apiResult.id))
        #expect(!store.addBook(BookFactory.makeBook(from: apiResult, status: .toRead, format: .physical)))
        await store.refreshSampleBooks(using: repository)
        #expect(repository.calls == 1)
        #expect(try dataSource.loadBooks() == store.books)
    }

    @Test func failedRefreshPreservesSampleAndAllowsRetry() async throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Book.mockFourthWing
        let store = LibraryStore(books: [original], localDataSource: dataSource)
        await store.refreshSampleBooks(using: OfflineRepository())
        #expect(store.books == [original])
        #expect(store.sampleRefreshError != nil)
        #expect(!store.isRefreshingSampleBooks)
        await store.refreshSampleBooks(using: StubRepository(result: apiResult))
        #expect(store.sampleRefreshError == nil)
        #expect(store.book(id: original.id)?.sourceBookID == apiResult.id)
    }


    @Test func yearlyGoalPersistsAndTracksCompletionChanges() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date()
        let year = Calendar.current.component(.year, from: now)
        let books = (1...3).map { Book(id: "goal-\($0)", title: "Test", authors: [], description: nil, coverURL: nil, pageCount: nil, status: .completed, format: .physical, completedAt: now) }
        let library = LibraryStore(books: books, localDataSource: dataSource)
        let repository = LocalJSONRepository<[ReadingGoal]>(fileName: "goals.json", directory: root)
        let model = ReadingGoalsViewModel(library: library, repository: repository)
        #expect(model.save(year: year, targetText: "12"))
        #expect(model.completedBooks(in: year) == 3)
        let goal = try #require(model.goal(for: year))
        #expect(Double(model.completedBooks(in: year)) / Double(goal.target) == 0.25)
        let restored = ReadingGoalsViewModel(library: library, repository: repository)
        #expect(restored.goal(for: year)?.target == 12)
        var changed = books[0]; changed.status = .reading
        library.updateBook(changed)
        // Starting a reread preserves the previous completion toward the goal.
        #expect(restored.completedBooks(in: year) == 3)
        #expect(library.book(id: changed.id)?.pastReads?.count == 1)
        #expect(library.book(id: changed.id)?.completedAt == nil)
        let savedBooks = try dataSource.loadBooks()
        let reloadedLibrary = LibraryStore(books: try #require(savedBooks), localDataSource: dataSource)
        #expect(ReadingGoalsViewModel(library: reloadedLibrary, repository: repository).completedBooks(in: year) == 3)
        #expect(model.completedBooks(in: year - 1) == 0)
    }

    @Test func goalsRejectInvalidTargetsAndPreserveCorruptFile() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalJSONRepository<[ReadingGoal]>(fileName: "goals.json", directory: root)
        let model = ReadingGoalsViewModel(library: LibraryStore(books: [], localDataSource: dataSource), repository: repository)
        for value in ["", " ", "0", "-1", "1.5", "abc", "10001"] { #expect(!model.save(year: 2026, targetText: value)) }
        #expect(model.goals.isEmpty)
        let invalid = Data("broken".utf8)
        try invalid.write(to: root.appendingPathComponent("goals.json"))
        model.reload()
        #expect(!model.canSave)
        #expect(!model.save(year: 2026, targetText: "12"))
        #expect(try Data(contentsOf: root.appendingPathComponent("goals.json")) == invalid)
    }


    @Test func customListsPersistWithoutChangingLibrary() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let books = (1...3).map { Book(id: "list-\($0)", title: "Test \($0)", authors: [], description: nil, coverURL: nil, pageCount: nil, status: .toRead, format: .physical) }
        let library = LibraryStore(books: books, localDataSource: dataSource)
        let repository = LocalJSONRepository<[CustomBookList]>(fileName: "lists.json", directory: root)
        let model = CustomListsViewModel(library: library, repository: repository)
        #expect(!model.save(id: nil, name: " ", description: "", bookIDs: []))
        #expect(model.save(id: nil, name: "Fantasy Favourites", description: "My favourites", bookIDs: books.map(\.id) + [books[0].id, "missing"]))
        let first = try #require(model.lists.first)
        #expect(first.bookIDs.count == 3)
        #expect(model.save(id: nil, name: "Another List", description: "", bookIDs: [books[0].id]))
        let restored = CustomListsViewModel(library: library, repository: repository)
        #expect(restored.lists.count == 2)
        #expect(restored.books(in: first) == books)
        #expect(restored.save(id: first.id, name: "Edited", description: "Updated", bookIDs: first.bookIDs))
        restored.remove(bookID: books[0].id, from: first.id)
        #expect(restored.list(id: first.id)?.bookIDs.count == 2)
        #expect(library.books == books)
        #expect(restored.delete(ids: [first.id]))
        #expect(library.books == books)
        #expect(CustomListsViewModel(library: library, repository: repository).lists.count == 1)
    }

    @Test func corruptCustomListsAreNotOverwritten() throws {
        let (root, dataSource) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("invalid".utf8)
        let url = root.appendingPathComponent("lists.json")
        try data.write(to: url)
        let model = CustomListsViewModel(library: LibraryStore(books: [], localDataSource: dataSource), repository: .init(fileName: "lists.json", directory: root))
        #expect(!model.canSave)
        #expect(!model.save(id: nil, name: "Test", description: "", bookIDs: []))
        #expect(try Data(contentsOf: url) == data)
    }


    @Test func dailyReminderReplacesRequestAndPersists() async throws {
        let (root, _) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalJSONRepository<ReadingReminderPreferences>(fileName: "reminders.json", directory: root)
        let service = ReminderTestService()
        let model = ReadingRemindersViewModel(repository: repository, notifications: service)
        #expect(await model.update(enabled: true, hour: 20, minute: 0))
        #expect(service.pending.count == 1)
        #expect(service.pending[LocalReadingNotificationService.identifier]?.hour == 20)
        #expect(await model.update(enabled: true, hour: 21, minute: 30))
        #expect(service.pending.count == 1)
        let restored = ReadingRemindersViewModel(repository: repository, notifications: service)
        await restored.reconcile()
        #expect(restored.preferences.hour == 21)
        #expect(restored.preferences.minute == 30)
        #expect(service.pending.count == 1)
        #expect(await restored.update(enabled: false, hour: 21, minute: 30))
        #expect(service.pending.isEmpty)
        #expect(try repository.load(default: .init()).isEnabled == false)
    }

    @Test func deniedReminderPermissionDoesNotEnableOrSchedule() async throws {
        let (root, _) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ReminderTestService()
        service.authorization = .notDetermined; service.grantsPermission = false
        let model = ReadingRemindersViewModel(repository: .init(fileName: "reminders.json", directory: root), notifications: service)
        #expect(!(await model.update(enabled: true, hour: 20, minute: 0)))
        #expect(service.permissionRequests == 1)
        #expect(model.permissionDenied)
        #expect(!model.preferences.isEnabled)
        #expect(service.pending.isEmpty)
    }

    @Test func reminderSchedulingFailurePreservesPreferences() async throws {
        let (root, _) = try makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ReminderTestService()
        let repository = LocalJSONRepository<ReadingReminderPreferences>(fileName: "reminders.json", directory: root)
        let model = ReadingRemindersViewModel(repository: repository, notifications: service)
        #expect(await model.update(enabled: true, hour: 20, minute: 0))
        service.failScheduling = true
        #expect(!(await model.update(enabled: true, hour: 21, minute: 0)))
        #expect(model.preferences.hour == 20)
        #expect(model.errorMessage != nil)
        #expect(try repository.load(default: .init()).hour == 20)
        #expect(!(await model.update(enabled: true, hour: 24, minute: 0)))
    }

    @Test func notificationRequestUsesOneDailyCalendarTrigger() throws {
        let request = LocalReadingNotificationService.request(hour: 20, minute: 0)
        #expect(request.identifier == LocalReadingNotificationService.identifier)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 0)
        #expect(trigger.nextTriggerDate() != nil)
    }

    private var apiResult: BookSearchResult {
        BookSearchResult(id: "/works/test", title: "Fourth Wing", authors: ["Rebecca Yarros"], description: "API description", coverURL: URL(string: "https://covers.openlibrary.org/b/id/1-L.jpg"), pageCount: 498)
    }
}

private final class IsolatedFileManager: FileManager, @unchecked Sendable {
    let root: URL
    init(root: URL) { self.root = root; super.init() }
    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] { [root] }
}

@MainActor
private final class StubRepository: BookRepository {
    let result: BookSearchResult
    private(set) var calls = 0
    init(result: BookSearchResult) { self.result = result }
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        calls += 1
        return [result]
    }
}

private struct OfflineRepository: BookRepository {
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        throw URLError(.notConnectedToInternet)
    }
}
@MainActor private final class ReminderTestService: ReadingNotificationScheduling {
    var authorization: ReminderPermission = .allowed
    var grantsPermission = true
    var permissionRequests = 0
    var failScheduling = false
    var pending: [String: DateComponents] = [:]
    func permission() async -> ReminderPermission { authorization }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        authorization = grantsPermission ? .allowed : .denied
        return grantsPermission
    }
    func schedule(hour: Int, minute: Int) async throws {
        if failScheduling { throw URLError(.cannotConnectToHost) }
        pending[LocalReadingNotificationService.identifier] = DateComponents(hour: hour, minute: minute)
    }
    func cancel() { pending.removeValue(forKey: LocalReadingNotificationService.identifier) }
}
