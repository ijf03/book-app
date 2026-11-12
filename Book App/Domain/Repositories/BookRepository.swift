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
    func details(for book: BookSearchResult) async throws -> BookSearchResult
    func synopsis(for book: BookSearchResult) async throws -> BookSearchResult
    func editions(workID: String, offset: Int) async throws -> [BookEdition]

    func searchBooks(
        query: String,
        filter: BookSearchFilter
    ) async throws -> [BookSearchResult]
}


extension BookRepository {
    func synopsis(for book: BookSearchResult) async throws -> BookSearchResult { try await details(for: book) }
    func details(for book: BookSearchResult) async throws -> BookSearchResult { book }
    func editions(workID: String, offset: Int) async throws -> [BookEdition] { [] }
}
