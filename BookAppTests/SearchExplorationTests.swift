import Testing
@testable import Book_App

@MainActor
struct SearchExplorationTests {
    @Test func repeatedExplorationCreatesFreshNavigationRequest() {
        let router = AppRouter()
        router.explore(author: "Jane Austen")
        let first = router.searchRequest
        router.explore(author: "Jane Austen")
        #expect(first?.id != router.searchRequest?.id)
        #expect(router.searchRequest?.author == "Jane Austen")
        #expect(router.searchRequest?.genre == nil)
    }

    @Test func authorSearchUsesAuthorFilter() async {
        let repository = ExplorationRepository()
        let model = SearchViewModel(repository: repository)
        model.selectedGenre = "Romance"
        model.apply(.init(author: "Jane Austen", genre: nil))
        await model.search()
        let request = repository.lastRequest
        #expect(model.selectedGenre == "All")
        #expect(request?.query == "Jane Austen")
        #expect(request?.filter == .author)
    }

    @Test func genreSearchWorksWithoutSearchTextAndClearsOldAuthor() async {
        let repository = ExplorationRepository()
        let model = SearchViewModel(repository: repository)
        model.apply(.init(author: "Jane Austen", genre: nil))
        model.apply(.init(author: nil, genre: "Fiction"))
        await model.search()
        let request = repository.lastRequest
        #expect(model.searchText.isEmpty)
        #expect(model.selectedFilter == .all)
        #expect(request?.query == #"subject:"Fiction""#)
        #expect(request?.filter == .all)

        model.selectedGenre = "All"
        await model.search()
        if case .idle = model.state {} else {
            Issue.record("Clearing the genre with an empty query should restore discovery.")
        }
    }

    @Test func combinedAuthorAndGenreUseAdvancedQuery() async {
        let repository = ExplorationRepository()
        let model = SearchViewModel(repository: repository)
        model.apply(.init(author: "Jane Austen", genre: "Romance"))
        await model.search()
        let request = repository.lastRequest
        #expect(request?.query == #"(author:"Jane Austen") AND subject:"Romance""#)
        #expect(request?.filter == .all)
    }
}

@MainActor
private final class ExplorationRepository: BookRepository {
    var lastRequest: (query: String, filter: BookSearchFilter)?

    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        lastRequest = (query, filter)
        return []
    }
}
