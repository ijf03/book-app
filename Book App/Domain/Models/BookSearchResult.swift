//
//  BookSearchResult.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

struct BookSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let authors: [String]
    let description: String?
    let coverURL: URL?
    let pageCount: Int?
    var genre: String? = nil
    var genres: [String]? = nil
    var metadata: BookMetadata? = nil
    var genreChips: [String] { GenreTags.normalized(genres ?? genre.map { [$0] } ?? []) }

    var authorText: String {
        authors.isEmpty
            ? "Unknown author"
            : authors.joined(separator: ", ")
    }
}
