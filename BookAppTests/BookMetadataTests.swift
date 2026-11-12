import Foundation
import Testing
@testable import Book_App

@MainActor struct BookMetadataTests {
    @Test func synopsisAcceptsBothOpenLibraryRepresentations() throws {
        for json in [#"{"description":"A synopsis","subjects":["Fantasy"]}"#,
                     #"{"description":{"type":"/type/text","value":"A synopsis"}}"#] {
            let dto = try JSONDecoder().decode(OpenLibraryWorkDTO.self, from: Data(json.utf8))
            #expect(dto.description?.value == "A synopsis")
        }
        #expect(try JSONDecoder().decode(OpenLibraryWorkDTO.self, from: Data("{}".utf8)).description == nil)
    }

    @Test func editionFieldsAndMissingPagesDecodeWithoutInventingData() throws {
        let json = #"{"key":"/books/OL1M","title":"Book","publishers":["Publisher"],"publish_date":"2001","languages":[{"key":"/languages/eng"}],"isbn_13":["9780140328721"],"physical_format":"Paperback","covers":[42]}"#
        let edition = try JSONDecoder().decode(OpenLibraryEditionDTO.self, from: Data(json.utf8)).edition
        #expect(edition.isValid && edition.pages == nil)
        #expect(edition.languages.count == 1 && edition.publishers == ["Publisher"])
        #expect(edition.isbn == ["9780140328721"] && edition.coverURL != nil)
        var invalid = edition
        invalid.id = "untrusted"
        #expect(!invalid.isValid)
    }

    @Test func chipsAndStatisticsUseSameDeduplicatedGenres() {
        let now = Date()
        var book = Book(id: "book", title: "Book", authors: [], status: .completed, format: .physical, completedAt: now)
        book.genres = ["Fantasy", " fantasy ", "Romance"]
        #expect(book.genreChips == ["Fantasy", "Romance"])
        let input = StatisticsInput(books: [book], sessions: [], reviews: [])
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: .current, now: now)
        let insights = ReadingInsightsCalculator.calculate(input, statistics: stats, calendar: .current, now: now)
        #expect(insights.genres.count == 2)
        #expect(insights.genres.allSatisfy { $0.count == 1 })
        #expect(insights.untaggedBooks == 0)
        #expect(OpenLibraryGenre.all(from: ["Fantasy fiction", "Romance", "England"]) == ["Fantasy", "Romance"])
    }

    @Test func metadataSyncRoundTripPreservesReaderFieldsAndSelectedEdition() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root)
        let journal = try LocalSyncRepository(userID: "A", scope: scope)
        scope.syncRepository = journal
        var book = Book(id: "/works/OL1W", title: "Book", authors: [], status: .reading, format: .ebook)
        book.progress = .init(page: 42, percentage: nil, timestampSeconds: nil)
        let library = LibraryStore(books: [], localDataSource: .init(scope: scope))
        #expect(library.addBook(book))
        var result = BookSearchResult(book: book)
        result.genres = ["Fantasy", "Romance"]
        result.metadata = .init(workID: book.id, edition: .init(id: "/books/OL1M", title: "Edition", languages: ["French"], pages: 200), fetchedAt: Date())
        library.applyMetadata(result, bookID: book.id, selectingEdition: true)
        #expect(library.books[0].progress.page == 42 && library.books[0].format == .ebook)
        #expect(library.books[0].pageCount == 200 && library.books[0].language == "French")
        var stale = result
        stale.metadata?.edition = nil
        library.applyMetadata(stale, bookID: book.id)
        #expect(library.books[0].metadata?.edition?.id == "/books/OL1M")
        let second = AccountStorageScope(directory: root.appendingPathComponent("second"))
        let remote = try LocalSyncRepository(userID: "A", scope: second)
        second.syncRepository = remote
        try remote.receive(journal.records)
        let restored = try LocalLibraryDataSource(scope: second).loadBooks()
        #expect(restored?.first?.metadata == library.books[0].metadata)
        #expect(restored?.first?.genreChips == ["Fantasy", "Romance"])
        scope.invalidate()
        library.applyMetadata(result, bookID: book.id)
        #expect(library.books[0].progress.page == 42)
    }

    @Test func offlineAndLateResponsesPreserveCachedMetadata() async {
        let original = BookSearchResult(id: "/works/OL1W", title: "Book", authors: [], description: "Cached synopsis", coverURL: nil, pageCount: nil)
        let model = BookMetadataViewModel(book: original)
        let scope = AccountStorageScope(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let repository = MetadataRepository()
        repository.shouldFail = true
        await model.load(using: repository, scope: scope)
        #expect(model.result.description == "Cached synopsis" && model.error != nil && !model.isLoading)
        repository.shouldFail = false
        repository.beforeReturn = { scope.invalidate() }
        await model.load(using: repository, scope: scope)
        #expect(model.result.description == "Cached synopsis")
    }

    @Test func customMoodsSurviveRestartReviewDeletionSyncAndStayAccountScoped() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root.appendingPathComponent("A"))
        let journal = try LocalSyncRepository(userID: "A", scope: scope)
        scope.syncRepository = journal
        let moods = ReviewMoodStore(scope: scope)
        #expect(moods.remember(" Dreamy ") == "Dreamy")
        #expect(moods.remember("dreamy") == "Dreamy")
        #expect(moods.saved.count == 1)
        #expect(ReviewMoodStore(scope: scope).choices(reviews: [], selected: "").contains("Dreamy"))
        let second = AccountStorageScope(directory: root.appendingPathComponent("second"))
        let remote = try LocalSyncRepository(userID: "A", scope: second)
        second.syncRepository = remote
        try remote.receive(journal.records)
        #expect(ReviewMoodStore(scope: second).saved.first?.name == "Dreamy")
        let other = ReviewMoodStore(scope: .init(directory: root.appendingPathComponent("B")))
        #expect(!other.choices(reviews: [], selected: "").contains("Dreamy"))
        scope.invalidate()
        #expect(moods.remember("New") == nil)
        moods.clear()
        #expect(moods.saved.isEmpty)
    }
}

@MainActor private final class MetadataRepository: BookRepository {
    var shouldFail = false
    var beforeReturn: (() -> Void)?
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] { [] }
    func details(for book: BookSearchResult) async throws -> BookSearchResult {
        await Task.yield()
        if shouldFail { throw URLError(.notConnectedToInternet) }
        beforeReturn?()
        return .init(id: book.id, title: book.title, authors: book.authors, description: "New synopsis", coverURL: nil, pageCount: nil)
    }
}
