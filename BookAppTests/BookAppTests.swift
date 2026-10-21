import Foundation
import Testing
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
