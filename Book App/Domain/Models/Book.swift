//
//  Book.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String

    var title: String
    var authors: [String]
    var description: String?
    var coverURL: URL?

    var pageCount: Int?
    var status: ReadingStatus
    var format: ReadingFormat

    var authorText: String {
        authors.joined(separator: ", ")
    }
}
