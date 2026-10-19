//
//  BookContentData.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation

struct BookContentData:
    Codable,
    Sendable
{
    var notes: [ReadingNote]
    var reviews: [BookReview]

    static let empty =
        BookContentData(
            notes: [],
            reviews: []
        )
}
