import Foundation
import Testing
@testable import Book_App

@MainActor
struct LibraryBrowsingTests {
    @Test func filtersSearchAndSortingDoNotChangeSavedLibraryOrder() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let books = [
            Book(id: "z", title: "Zebra", authors: ["Amy"], status: .reading, format: .physical),
            Book(id: "a", title: "Alpha", authors: ["Zoe"], status: .completed, format: .ebook),
            Book(id: "b", title: "Beta", authors: ["Amy"], status: .toRead, format: .physical)
        ]
        let store = LibraryStore(books: books, localDataSource: LocalLibraryDataSource(scope: .init(directory: directory)))
        let model = LibraryViewModel(store: store)
        #expect(model.filteredBooks.map(\.id) == ["z", "a", "b"])
        model.sort = .title
        #expect(model.filteredBooks.map(\.id) == ["a", "b", "z"])
        model.searchText = "  AMY  "
        #expect(model.filteredBooks.map(\.id) == ["b", "z"])
        model.selectedStatus = .reading
        #expect(model.filteredBooks.map(\.id) == ["z"])
        #expect(model.count(for: .completed) == 1)
        #expect(store.books.map(\.id) == ["z", "a", "b"])
        model.searchText = "missing"
        #expect(model.filteredBooks.isEmpty)
        #expect(model.totalCount == 3)
    }
}
