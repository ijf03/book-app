import Foundation
import Testing
@testable import Book_App

@MainActor
struct ListSearchTests {
    @Test func catalogueSelectionIsDeferredAndReusesExistingIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let store = LibraryStore(books: [], localDataSource: LocalLibraryDataSource(scope: scope))
        let model = CustomListsViewModel(library: store)
        let result = BookSearchResult(id: "/works/new", title: "New book", authors: ["Author"], description: nil, coverURL: nil, pageCount: 200)
        let draft = model.book(for: result)
        #expect(store.books.isEmpty) // Selecting/cancelling has no persistence effect.
        #expect(model.saveSelection(id: nil, name: "Search list", description: "", books: [draft, draft]))
        #expect(store.books.count == 1)
        #expect(store.books.first?.status == .toRead)
        #expect(model.lists.first?.bookIDs == [result.id])

        var existing = Book(id: "legacy", title: "Existing", authors: [], status: .reading, format: .ebook)
        existing.sourceBookID = "/works/existing"
        existing.progress.page = 25
        #expect(store.addBook(existing))
        let remote = BookSearchResult(id: "/works/existing", title: "Remote", authors: [], description: nil, coverURL: nil, pageCount: nil)
        let resolved = model.book(for: remote)
        #expect(resolved.id == existing.id)
        let id = try #require(model.lists.first?.id)
        #expect(model.saveSelection(id: id, name: "Search list", description: "", books: [draft, resolved]))
        #expect(store.books.count == 2)
        #expect(store.book(id: "legacy")?.progress.page == 25)
        #expect(store.book(id: "legacy")?.status == .reading)
        #expect(model.list(id: id)?.bookIDs == ["/works/new", "legacy"])
    }

    @Test func revokedAccountCannotSaveSelectedSearchBooks() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let store = LibraryStore(books: [], localDataSource: LocalLibraryDataSource(scope: scope))
        let model = CustomListsViewModel(library: store)
        let result = BookSearchResult(id: "new", title: "Book", authors: [], description: nil, coverURL: nil, pageCount: nil)
        let draft = model.book(for: result)
        scope.invalidate()
        #expect(!model.saveSelection(id: nil, name: "Late list", description: "", books: [draft]))
        #expect(store.books.isEmpty)
        #expect(model.lists.isEmpty)
    }
}
