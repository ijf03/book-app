//
//  HomeViewModel.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {

    private let store: LibraryStore

    init(store: LibraryStore) {
        self.store = store
    }

    // MARK: - Sections

    var currentlyReadingBooks: [Book] {
        store.books.filter {
            $0.status == .reading
        }
    }

    var upNextBooks: [Book] {
        store.books.filter {
            $0.status == .toRead
        }
    }

    var completedBooks: [Book] {
        store.books.filter {
            $0.status == .completed
        }
    }

    // MARK: - Summary

    var readingCount: Int {
        currentlyReadingBooks.count
    }

    var toReadCount: Int {
        upNextBooks.count
    }

    var completedCount: Int {
        completedBooks.count
    }

    // MARK: - Library Changes

    func updateBook(
        _ updatedBook: Book
    ) {
        store.updateBook(
            updatedBook
        )
    }

    func removeBook(
        id: String
    ) {
        store.removeBook(
            id: id
        )
    }
}
