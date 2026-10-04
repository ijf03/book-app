//
//  LibraryViewModel.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {

    private let store: LibraryStore

    var selectedStatus: ReadingStatus = .reading
    var searchText = ""

    init(store: LibraryStore) {
        self.store = store
    }

    var filteredBooks: [Book] {
        store.books.filter { book in

            let matchesStatus =
                book.status == selectedStatus

            let trimmedSearch =
                searchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let matchesSearch =
                trimmedSearch.isEmpty ||
                book.title
                    .localizedCaseInsensitiveContains(
                        trimmedSearch
                    ) ||
                book.authors.contains {
                    $0.localizedCaseInsensitiveContains(
                        trimmedSearch
                    )
                }

            return matchesStatus &&
                matchesSearch
        }
    }

    var hasSearchQuery: Bool {
        !searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    func updateBook(
        _ updatedBook: Book
    ) {
        store.updateBook(
            updatedBook
        )
    }
}
