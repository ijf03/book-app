//
//  LibraryStore.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {

    private(set) var books: [Book]

    init(books: [Book]) {
        self.books = books
    }

    // MARK: - Add

    @discardableResult
    func addBook(_ book: Book) -> Bool {
        guard !contains(bookID: book.id) else {
            return false
        }

        books.append(book)
        return true
    }

    // MARK: - Update

    func updateBook(_ updatedBook: Book) {
        guard let index = books.firstIndex(
            where: { $0.id == updatedBook.id }
        ) else {
            return
        }

        books[index] = updatedBook
    }

    // MARK: - Remove

    func removeBook(id: String) {
        books.removeAll {
            $0.id == id
        }
    }

    // MARK: - Lookup

    func contains(bookID: String) -> Bool {
        books.contains {
            $0.id == bookID
        }
    }

    func book(id: String) -> Book? {
        books.first {
            $0.id == id
        }
    }
}
