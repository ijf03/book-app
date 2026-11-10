import Foundation
import Observation

@MainActor @Observable
final class LibraryViewModel {
    enum Sort: String, CaseIterable, Identifiable {
        case saved, title, author
        var id: Self { self }
        var label: LocalizedStringResource {
            switch self { case .saved: "Library order"; case .title: "Title"; case .author: "Author" }
        }
    }
    private let store: LibraryStore
    var selectedStatus: ReadingStatus? = nil
    var searchText = ""
    var sort: Sort = .saved

    init(store: LibraryStore) { self.store = store }

    var totalCount: Int { store.books.count }
    func count(for status: ReadingStatus) -> Int { store.books.filter { $0.status == status }.count }

    var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let books = store.books.filter { book in
            (selectedStatus == nil || book.status == selectedStatus)
                && (query.isEmpty || book.title.localizedCaseInsensitiveContains(query)
                    || book.authors.contains { $0.localizedCaseInsensitiveContains(query) })
        }
        guard sort != .saved else { return books }
        return books.sorted {
            let left = sort == .title ? $0.title : $0.authorText
            let right = sort == .title ? $1.title : $1.authorText
            let comparison = left.localizedStandardCompare(right)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
    var hasSearchQuery: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func updateBook(_ book: Book) { store.updateBook(book) }
    func removeBook(id: String) { store.removeBook(id: id) }
}
