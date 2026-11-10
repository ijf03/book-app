import Foundation
import Testing
@testable import Book_App

@MainActor
struct OpenLibraryGenreTests {
    @Test func decodesSubjectsAndPreservesGenreWhenAddingBook() throws {
        let dto = try JSONDecoder().decode(OpenLibraryBookDTO.self, from: Data(#"{"key":"/works/OL1W","title":"Book","subject":["Fiction","Fantasy fiction","England"]}"#.utf8))
        #expect(dto.subjects?.count == 3)
        let genre = OpenLibraryGenre.primary(from: dto.subjects ?? [])
        #expect(genre == "Fantasy")
        let result = BookSearchResult(id: dto.key, title: dto.title, authors: [], description: nil, coverURL: nil, pageCount: nil, genre: genre)
        #expect(BookFactory.makeBook(from: result, status: .toRead, format: .physical).genre == "Fantasy")
        #expect(OpenLibraryGenre.primary(from: ["England", "Women", "Accessible book"]) == nil)
        #expect(OpenLibraryGenre.primary(from: ["Fiction, Science fiction, General"]) == "Science fiction")
        let missing = try JSONDecoder().decode(OpenLibraryBookDTO.self, from: Data(#"{"key":"/works/OL2W","title":"Book"}"#.utf8))
        #expect(missing.subjects == nil)
    }

    @Test func fillsExactMatchPreservesManualGenreAndCompletionDate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = AccountStorageScope(directory: root)
        let source = LocalLibraryDataSource(scope: scope)
        let one = Book(id: "/works/OL1W", title: "Book", authors: ["Author"], status: .completed, format: .physical)
        var two = one
        two.sourceBookID = "/works/OL2W"
        two.genre = "My genre"
        let library = LibraryStore(books: [one], localDataSource: source)
        let repository = GenreRepository()
        let model = GenreMetadataViewModel()
        await model.fillMissing(library: library, repository: repository)
        #expect(library.books.first?.genre == "Fantasy")
        #expect(library.books.first?.completedAt == nil)
        #expect(try source.loadBooks()?.first?.genre == "Fantasy")
        #expect(repository.queries == ["key:\"/works/OL1W\""])
        library.updateGenre(bookID: one.id, genre: two.genre)
        await model.fillMissing(library: library, repository: repository)
        #expect(library.books.first?.genre == "My genre")
        #expect(repository.queries.count == 1)
    }

    @Test func revokedAccountRejectsLateMetadataAndWrongIdentityIsNotApplied() async {
        let scope = AccountStorageScope(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let book = Book(id: "/works/OL99W", title: "Book", authors: [], status: .reading, format: .physical)
        let library = LibraryStore(books: [book], localDataSource: LocalLibraryDataSource(scope: scope))
        let repository = GenreRepository()
        let model = GenreMetadataViewModel()
        await model.fillMissing(library: library, repository: repository)
        #expect(library.books.first?.genre == nil)
        repository.beforeReturn = { scope.invalidate() }
        await model.fillMissing(library: library, repository: repository)
        #expect(library.books.first?.genre == nil)
    }
}

@MainActor private final class GenreRepository: BookRepository {
    var queries: [String] = []
    var beforeReturn: (() -> Void)?
    func searchBooks(query: String, filter: BookSearchFilter) async throws -> [BookSearchResult] {
        queries.append(query)
        await Task.yield()
        beforeReturn?()
        return [.init(id: "/works/OL1W", title: "Book", authors: ["Author"], description: nil, coverURL: nil, pageCount: nil, genre: "Fantasy")]
    }
}
