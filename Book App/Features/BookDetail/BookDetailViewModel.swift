//
//  BookDetailViewModel.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class BookDetailViewModel {
    var book: Book

    init(book: Book) {
        self.book = book
    }

    var statusTitle: String {
        switch book.status {
        case .reading:
            return "Currently reading"

        case .toRead:
            return "To Read"

        case .completed:
            return "Completed"
        }
    }

    var primaryActionTitle: String {
        switch book.status {
        case .reading:
            return "Start a Reading Session"

        case .toRead:
            return "Start Reading"

        case .completed:
            return "Read Again"
        }
    }

    var shouldShowReadingProgress: Bool {
        book.status == .reading
    }
}
