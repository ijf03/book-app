//
//  OpenLibraryDTO.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import Foundation

struct OpenLibrarySearchResponseDTO: Decodable, Sendable {
    let docs: [OpenLibraryBookDTO]
}

struct OpenLibraryBookDTO: Decodable, Sendable {
    let key: String
    let title: String
    let authorName: [String]?
    let coverID: Int?
    let firstPublishYear: Int?
    let editionKey: [String]?
    let numberOfPagesMedian: Int?

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case coverID = "cover_i"
        case firstPublishYear = "first_publish_year"
        case editionKey = "edition_key"
        case numberOfPagesMedian = "number_of_pages_median"
    }
}
