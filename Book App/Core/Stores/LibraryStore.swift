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
    /// Hydration never saves back to the repository, avoiding listener feedback.
    func reloadFromLocalSync() {
        checkIns.reload()
        profile.reload()
        do {
            books = try localDataSource.loadBooks() ?? []
            persistenceError = nil
        } catch { persistenceError = SyncFailure.localStorage.message }
    }

    func clearAccountMemory() { profile.clear(); checkIns.clear(); books = []; sampleRefreshError = nil; persistenceError = nil }


    let profile: ReaderProfileStore
    let checkIns: ReadingCheckInStore
    private(set) var books: [Book]

    private let localDataSource:
        LocalLibraryDataSource

    private(set) var persistenceError:
        String?

    init(
        books: [Book],
        localDataSource: LocalLibraryDataSource
    ) {
        // Loading history must not manufacture completion dates or upload inferred edits.
        self.profile = ReaderProfileStore(scope: localDataSource.scope)
        self.checkIns = ReadingCheckInStore(scope: localDataSource.scope)
        self.books = books
        self.localDataSource = localDataSource
    }

    var accountScope: AccountStorageScope? { localDataSource.scope }

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

        var savedBook = book
        if savedBook.status == .completed && savedBook.completedAt == nil { savedBook.completedAt = Date() }
        if savedBook.status == .abandoned && savedBook.abandonedAt == nil { savedBook.abandonedAt = Date() }
        if savedBook.status == .reading && savedBook.currentReadStartedAt == nil { savedBook.currentReadStartedAt = Date() }
        savedBook.formatsUsed = [savedBook.format]
        books.append(savedBook)

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

    /// Editing a genre must not invent a completion date for an undated legacy book.
    func updateGenre(bookID: String, genre: String?) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        let previous = books[index]
        books[index].genre = genre
        books[index].genres = genre.map { [$0] } ?? []
        if !save() { books[index] = previous }
    }

    /// Merge only catalogue fields into the latest record; never replace progress or review history.
    func applyMetadata(_ result: BookSearchResult, bookID: String, selectingEdition: Bool = false, fillGenres: Bool = false) {
        guard accountScope?.isActive != false,
              let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        let old = books[index]
        books[index].description = result.description ?? old.description
        if var metadata = result.metadata {
            if !selectingEdition { metadata.edition = old.metadata?.edition }
            books[index].metadata = metadata
        }
        if old.genres == nil || (fillGenres && old.genreChips.isEmpty) {
            books[index].genres = GenreTags.normalized(old.genreChips + result.genreChips)
            books[index].genre = books[index].genres?.first
        }
        if selectingEdition, let edition = result.metadata?.edition {
            let fraction = old.progress.normalizedFraction(pageCount: old.pageCount, audioDuration: old.audioDurationSeconds)
            if let fraction {
                books[index].progress.percentage = fraction * 100
                if old.pageCount != edition.pages { books[index].progress.page = nil }
            }
            books[index].pageCount = edition.pages
            books[index].language = edition.languages.first
            books[index].coverURL = edition.coverURL ?? old.coverURL
        }
        if !save() { books[index] = old }
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

        // A stale progress editor must not overwrite a newer reading cycle.
        guard updatedBook.currentReadID == oldBook.currentReadID else { return }
        var savedBook = updatedBook
        savedBook.pastReads = oldBook.pastReads
        savedBook.currentReadStartedAt = oldBook.currentReadStartedAt
        if oldBook.status == .completed && savedBook.status == .reading {
            savedBook = oldBook
            savedBook.beginReread()
        } else if oldBook.status == .toRead && savedBook.status == .reading {
            savedBook.currentReadStartedAt = Date()
        }
        savedBook.completedAt = savedBook.status == .completed
            ? (oldBook.status == .completed ? oldBook.completedAt : Date())
            : nil
        savedBook.abandonedAt = savedBook.status == .abandoned
            ? (oldBook.abandonedAt ?? Date()) : nil
        savedBook.formatsUsed = ReadingFormat.allCases.filter {
            Set((oldBook.formatsUsed ?? [oldBook.format]) + [savedBook.format]).contains($0)
        }
        books[index] = savedBook

        if !save() {
            // Restore old value if persistence failed.
            books[index] =
                oldBook
        }
    }

    /// Append to the latest book so an open sheet cannot overwrite newer progress.
    /// The stable draft ID makes repeated save attempts idempotent.
    func addPastRead(bookID: String, id: String, start: Date?, end: Date?) -> Bool {
        guard PastRead.validation(start: start, end: end) == nil,
              let index = books.firstIndex(where: { $0.id == bookID }) else { return false }
        if books[index].pastReads?.contains(where: { $0.id == id }) == true { return true }
        guard !id.isEmpty, id.count <= 100, id != (books[index].currentReadID ?? "initial"),
              (books[index].pastReads?.count ?? 0) < 10000 else { return false }
        let previous = books[index]
        var history = previous.pastReads ?? []
        history.append(PastRead(id: id, startedAt: start, completedAt: end,
                                format: previous.format, progress: .empty))
        books[index].pastReads = history
        if save() { return true }
        books[index] = previous
        return false
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
