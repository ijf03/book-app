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
    var books: [Book]
    var selectedStatus: ReadingStatus = .reading
    var searchText = ""

    init(books: [Book]) {
        self.books = books
    }

    convenience init() {
        self.init(books: Book.mockBooks)
    }

    var filteredBooks: [Book] {
        books.filter { book in
            let matchesStatus = book.status == selectedStatus

            let matchesSearch =
                searchText.isEmpty ||
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.authors.contains {
                    $0.localizedCaseInsensitiveContains(searchText)
                }

            return matchesStatus && matchesSearch
        }
    }

    var hasSearchQuery: Bool {
        !searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
    
    func updateBook(_ updatedBook: Book) {
        guard
            let index = books.firstIndex(
                where: {
                    $0.id == updatedBook.id
                }
            )
        else {
            return
        }

        books[index] = updatedBook
    }
}
