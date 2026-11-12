import Foundation
import Testing
@testable import Book_App

@MainActor
struct BookDiscoveryTests {
    private func result(_ id: String) -> BookSearchResult {
        .init(id: id, title: id, authors: ["Author"], description: nil, coverURL: nil, pageCount: nil)
    }

    @Test func genreDefaultsToAllAndExplicitSelectionFiltersDiscoveryAndSearch() async {
        let repository = DiscoveryRepository(results: [])
        let discovery = BookDiscoveryViewModel(repository: repository)
        #expect(discovery.topic == "All")
        #expect(BookDiscoveryViewModel.seeds(books: [], topic: "All").first?.query == "*")
        discovery.topic = "Mystery"
        await discovery.load(books: [Book.mockFourthWing], scope: nil)
        #expect(repository.queries == ["subject:\"Mystery\""])
        let search = SearchViewModel(repository: repository)
        search.searchText = "Lewis"
        await search.search()
        #expect(repository.queries.last == "Lewis")
        search.selectedGenre = "Fantasy"
        await search.search()
        #expect(repository.queries.last == "(Lewis) AND subject:\"Fantasy\"")
    }

    @Test func seedsUseActualReadingHistoryAndProvideNewReaderFallback() {
        let fallback = BookDiscoveryViewModel.seeds(books: [], topic: "Mystery")
        #expect(fallback.count == 1 && fallback[0].query == "subject:\"Mystery\"")
        var book = Book.mockFourthWing
        book.status = .reading
        book.genre = "Fantasy"
        let seeds = BookDiscoveryViewModel.seeds(books: [book], topic: "History")
        #expect(seeds.count == 3)
        #expect(seeds[0].filter == .author && seeds[0].query == book.authors[0])
        #expect(seeds[1].query == "subject:\"Fantasy\"")
        book.status = .toRead
        #expect(BookDiscoveryViewModel.seeds(books: [book], topic: "History").count == 1)
        #expect(BookDiscoveryViewModel.subjectQuery("A\"B") == "subject:\"A\\\"B\"")
    }

    @Test func ownedLegacyAndDuplicateResultsAreExcludedAndLoadsAreCached() async {
        var book = Book.mockFourthWing
        book.sourceBookID = "/works/owned"
        let repository = DiscoveryRepository(results: [result("/works/owned"), result("new"), result("new")])
        let model = BookDiscoveryViewModel(repository: repository)
        await model.load(books: [book], scope: nil)
        #expect(model.shelves.flatMap(\.books).map(\.id) == ["new"])
        let count = repository.calls
        await model.load(books: [book], scope: nil)
        #expect(repository.calls == count)
        await model.load(books: [book], scope: nil, force: true)
        #expect(repository.calls > count)
    }

    @Test func networkFailureCanBeRetriedWithoutBlockingSearch() async {
        let repository = DiscoveryRepository(results: [result("new")], fails: true)
        let model = BookDiscoveryViewModel(repository: repository)
        await model.load(books: [], scope: nil)
        #expect(model.error != nil && !model.isLoading && model.shelves.isEmpty)
        repository.recover()
        await model.load(books: [], scope: nil)
        #expect(model.error == nil && model.shelves.first?.books.first?.id == "new")
    }

    @Test func featuredPreferHistoryMatchesAndPreserveFullSynopsis() async {
        var owned = Book.mockFourthWing
        owned.status = .reading
        let synopsis = String(repeating: "A complete synopsis paragraph.\n\n", count: 20)
        let unrelated = BookSearchResult(id: "other", title: "Other", authors: ["Someone else"],
                                       description: synopsis, coverURL: nil, pageCount: nil)
        let matching = BookSearchResult(id: "match", title: "Match", authors: owned.authors,
                                      description: synopsis, coverURL: nil, pageCount: nil)
        let repository = DiscoveryRepository(results: [unrelated, matching, matching])
        let model = BookDiscoveryViewModel(repository: repository)
        await model.load(books: [owned], scope: nil)
        #expect(model.featured.map(\.id) == ["match", "other"])
        #expect(model.featured.first?.book.description == synopsis)
    }

    @Test func automaticSynopsesAreLimitedToTwoAndMoreBooksLoadOnDemand() async {
        let results = (0..<12).map { index in
            BookSearchResult(id: "book-\(index)", title: "Book", authors: [],
                             description: index < 2 ? "  " : "Full synopsis \(index)",
                             coverURL: nil, pageCount: nil)
        }
        let repository = DiscoveryRepository(results: results)
        let model = BookDiscoveryViewModel(repository: repository)
        await model.load(books: [], scope: nil)
        #expect(model.featured.map(\.id) == ["book-0", "book-1"])
        #expect(model.moreToExplore.map(\.id) == ["book-2", "book-3"])
        #expect(repository.detailCalls == 2)
        let missing = DiscoveryRepository(results: (0..<12).map { result("missing-\($0)") })
        let fallback = BookDiscoveryViewModel(repository: missing)
        await fallback.load(books: [], scope: nil)
        #expect(missing.detailCalls == 2)
        #expect(fallback.featured.count == 2 && fallback.moreToExplore.count == 2)
    }

    @Test func revokedAccountDiscardsInFlightResults() async {
        let repository = SuspendedDiscoveryRepository()
        let model = BookDiscoveryViewModel(repository: repository)
        let scope = AccountStorageScope(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let task = Task { await model.load(books: [], scope: scope) }
        while !(repository.isWaiting) { await Task.yield() }
        scope.invalidate()
        repository.finish([result("late")])
        await task.value
        #expect(model.shelves.isEmpty && !model.isLoading)
    }
}

@MainActor private final class DiscoveryRepository: BookRepository {
    let results: [BookSearchResult]
    var fails: Bool
    private(set) var calls = 0
    private(set) var queries: [String] = []
    private(set) var detailCalls = 0
    func details(for book: BookSearchResult) async throws -> BookSearchResult {
        detailCalls += 1
        return book
    }
    init(results: [BookSearchResult], fails: Bool = false) { self.results = results; self.fails = fails }
    func recover() { fails = false }
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        calls += 1
        queries.append(query)
        if fails { throw URLError(.notConnectedToInternet) }
        return results
    }
}

@MainActor private final class SuspendedDiscoveryRepository: BookRepository {
    private var continuation: CheckedContinuation<[BookSearchResult], Never>?
    var isWaiting: Bool { continuation != nil }
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ results: [BookSearchResult]) { continuation?.resume(returning: results); continuation = nil }
}
