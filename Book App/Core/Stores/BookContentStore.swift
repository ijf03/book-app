//
//  BookContentStore.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class BookContentStore {
    /// Hydration never saves back to the repository, avoiding listener feedback.
    func reloadFromLocalSync() {
        do {
            let content = try localDataSource.loadContent()
            notes = content.notes
            reviews = content.reviews
            persistenceError = nil
        } catch { persistenceError = SyncFailure.localStorage.message }
    }

    func clearAccountMemory() { notes = []; reviews = []; persistenceError = nil }


    private(set) var notes:
        [ReadingNote]

    private(set) var reviews:
        [BookReview]

    private let localDataSource:
        LocalBookContentDataSource

    private(set) var persistenceError:
        String?

    init(
        notes: [ReadingNote],
        reviews: [BookReview],
        localDataSource:
            LocalBookContentDataSource
    ) {
        self.notes = notes
        self.reviews = reviews
        self.localDataSource =
            localDataSource
    }

    // MARK: - Notes

    /// Publish only after the local repository accepts the note. Cloud upload remains asynchronous.
    @discardableResult
    func saveProgressNote(_ note: ReadingNote) -> Bool {
        var updated = notes
        if let index = updated.firstIndex(where: { $0.id == note.id }) { updated[index] = note }
        else { updated.append(note) }
        do {
            try localDataSource.saveContent(BookContentData(notes: updated, reviews: reviews))
            notes = updated
            persistenceError = nil
            return true
        } catch {
            persistenceError = String(localized: "Your note couldn’t be saved. Please try again.")
            return false
        }
    }

    func notes(
        for bookID: String
    ) -> [ReadingNote] {

        notes
            .filter {
                $0.bookID == bookID
            }
            .sorted {

                if let firstPage =
                    $0.page,
                   let secondPage =
                    $1.page,
                   firstPage != secondPage
                {
                    return firstPage <
                        secondPage
                }

                return $0.updatedAt >
                    $1.updatedAt
            }
    }

    func addNote(
        _ note: ReadingNote
    ) {
        notes.append(note)
        save()
    }

    func updateNote(
        _ updatedNote:
            ReadingNote
    ) {
        guard let index =
            notes.firstIndex(
                where: {
                    $0.id ==
                        updatedNote.id
                }
            )
        else {
            return
        }

        notes[index] =
            updatedNote

        save()
    }

    func deleteNote(
        id: UUID
    ) {
        notes.removeAll {
            $0.id == id
        }

        save()
    }

    // MARK: - Review

    func review(
        for bookID: String
    ) -> BookReview? {

        reviews.first {
            $0.bookID ==
                bookID
        }
    }

    func saveReview(
        _ review: BookReview
    ) {
        if let index =
            reviews.firstIndex(
                where: {
                    $0.bookID ==
                        review.bookID
                }
            )
        {
            reviews[index] =
                review
        } else {
            reviews.append(
                review
            )
        }

        save()
    }

    func deleteReview(
        for bookID: String
    ) {
        reviews.removeAll {
            $0.bookID ==
                bookID
        }

        save()
    }

    // MARK: - Remove Book Data

    func deleteAllContent(
        for bookID: String
    ) {
        notes.removeAll {
            $0.bookID ==
                bookID
        }

        reviews.removeAll {
            $0.bookID ==
                bookID
        }

        save()
    }

    // MARK: - Persistence

    private func save() {

        do {
            try localDataSource
                .saveContent(
                    BookContentData(
                        notes: notes,
                        reviews: reviews
                    )
                )

            persistenceError =
                nil

        } catch {

            persistenceError =
                error.localizedDescription

            print(
                "❌ Failed to persist notes/reviews:",
                error
            )
        }
    }
}
