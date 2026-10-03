//
//  BookRepository.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

enum BookSearchFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case title
    case author

    var id: Self { self }

    var displayName: String {
        switch self {
        case .all:
            return "All"

        case .title:
            return "Title"

        case .author:
            return "Author"
        }
    }
}

protocol BookRepository: Sendable {
    func searchBooks(
        query: String,
        filter: BookSearchFilter
    ) async throws -> [BookSearchResult]
}
