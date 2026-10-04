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

    private let localDataSource:
        LocalLibraryDataSource

    private(set) var persistenceError:
        String?

    init(
        books: [Book],
        localDataSource: LocalLibraryDataSource
    ) {
        self.books = books
        self.localDataSource = localDataSource
    }

    // MARK: - Add

    @discardableResult
    func addBook(
        _ book: Book
    ) -> Bool {

        guard !contains(
            bookID: book.id
        ) else {
            print(
                "ℹ️ Book already exists:",
                book.title
            )

            return false
        }

        books.append(book)

        print(
            "➕ Added to LibraryStore:",
            book.title
        )

        if save() {
            return true
        }

        // Saving failed, so undo the in-memory addition.
        books.removeAll {
            $0.id == book.id
        }

        return false
    }

    // MARK: - Update

    func updateBook(
        _ updatedBook: Book
    ) {

        guard let index =
            books.firstIndex(
                where: {
                    $0.id == updatedBook.id
                }
            )
        else {
            return
        }

        let oldBook =
            books[index]

        books[index] =
            updatedBook

        if !save() {
            // Restore old value if persistence failed.
            books[index] =
                oldBook
        }
    }

    // MARK: - Remove

    func removeBook(
        id: String
    ) {

        guard let index =
            books.firstIndex(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        let removedBook =
            books.remove(
                at: index
            )

        if !save() {
            books.insert(
                removedBook,
                at: index
            )
        }
    }

    // MARK: - Lookup

    func contains(
        bookID: String
    ) -> Bool {

        books.contains {
            $0.id == bookID
        }
    }

    func book(
        id: String
    ) -> Book? {

        books.first {
            $0.id == id
        }
    }

    // MARK: - Persistence

    @discardableResult
    private func save() -> Bool {

        do {
            try localDataSource
                .saveBooks(
                    books
                )

            persistenceError = nil

            print(
                "✅ LibraryStore persistence succeeded."
            )

            return true

        } catch {

            print(
                "❌ Failed to persist library:",
                error.localizedDescription
            )

            persistenceError =
                error.localizedDescription

            return false
        }
    }
}
