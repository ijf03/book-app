//
//  ReadingProgress.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import Foundation

struct ReadingProgress: Codable, Hashable, Sendable {
    var page: Int?
    var percentage: Double?
    var timestampSeconds: Int?

    static let empty = ReadingProgress(
        page: nil,
        percentage: nil,
        timestampSeconds: nil
    )
}
