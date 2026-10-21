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
            $0.id == bookID || $0.sourceBookID == bookID
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

    // MARK: - Replace Legacy Sample Metadata

    private(set) var isRefreshingSampleBooks = false
    private(set) var sampleRefreshError: String?

    func dismissSampleRefreshError() { sampleRefreshError = nil }

    func refreshSampleBooks(using repository: any BookRepository) async {
        guard !isRefreshingSampleBooks else { return }
        isRefreshingSampleBooks = true
        sampleRefreshError = nil
        defer { isRefreshingSampleBooks = false }

        // Only IDs from the old bundled sample library are eligible.
        // Local identity and reader-owned fields remain unchanged.
        let samples: [(id: String, title: String, author: String)] = [
            ("fourth-wing", "Fourth Wing", "Rebecca Yarros"),
            ("tomorrow", "Tomorrow, and Tomorrow, and Tomorrow", "Gabrielle Zevin"),
            ("project-hail-mary", "Project Hail Mary", "Andy Weir"),
            ("iron-flame", "Iron Flame", "Rebecca Yarros"),
            ("dune", "Dune", "Frank Herbert"),
            ("circe", "Circe", "Madeline Miller"),
            ("six-of-crows", "Six of Crows", "Leigh Bardugo"),
            ("long-title", "The Hitchhiker’s Guide to the Galaxy", "Douglas Adams"),
            ("two-authors", "Good Omens", "Terry Pratchett"),
            ("no-description", "The Midnight Library", "Matt Haig"),
            ("no-page-count", "The Hobbit", "J. R. R. Tolkien"),
            ("no-cover", "The Night Circus", "Erin Morgenstern"),
            ("long-authors", "Neverwhere", "Neil Gaiman"),
            ("short-book", "Animal Farm", "George Orwell"),
            ("huge-book", "The Way of Kings", "Brandon Sanderson")
        ]

        var failedCount = 0
        for sample in samples {
            guard let existing = book(id: sample.id), existing.sourceBookID == nil else { continue }
            do {
                try Task.checkCancellation()
                let results = try await repository.searchBooks(query: sample.title, filter: .title)
                try Task.checkCancellation()
                guard let result = results.first(where: { candidate in
                    candidate.authors.contains { author in
                        author.lowercased().filter(\.isLetter)
                            .contains(sample.author.lowercased().filter(\.isLetter))
                    }
                }) else {
                    failedCount += 1
                    continue
                }
                // Re-read after the network suspension: the user may have edited or removed it.
                guard var updated = book(id: sample.id), updated.sourceBookID == nil else { continue }
                updated.title = result.title
                updated.authors = result.authors
                updated.description = result.description
                updated.coverURL = result.coverURL
                updated.pageCount = result.pageCount
                updated.sourceBookID = result.id
                updateBook(updated)
                if persistenceError != nil { failedCount += 1 }
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                failedCount += 1
            }
        }
        if failedCount > 0 {
            sampleRefreshError = "Some sample books couldn’t be refreshed. Your saved data is unchanged for those books. Check your connection and try again."
        }
    }
}
