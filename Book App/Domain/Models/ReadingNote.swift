//
//  ReadingNote.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation

struct ReadingNote:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    let id: UUID
    let bookID: String

    var text: String
    var page: Int?
    var containsSpoilers: Bool

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookID: String,
        text: String,
        page: Int? = nil,
        containsSpoilers: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookID = bookID
        self.text = text
        self.page = page
        self.containsSpoilers =
            containsSpoilers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
