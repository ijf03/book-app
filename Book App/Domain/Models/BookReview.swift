//
//  BookReview.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation

struct BookReview:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    let id: UUID
    let bookID: String

    var mood: String? = nil
    var rating: Int
    var text: String
    var containsSpoilers: Bool

    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        bookID: String,
        rating: Int,
        text: String,
        containsSpoilers: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        mood: String? = nil
    ) {
        self.mood = mood
        self.id = id
        self.bookID = bookID
        self.rating = rating
        self.text = text
        self.containsSpoilers =
            containsSpoilers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
