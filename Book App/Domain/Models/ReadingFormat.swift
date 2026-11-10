//
//  ReadingFormat.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation

enum ReadingFormat: String, Codable, CaseIterable, Identifiable {
    case physical
    case ebook
    case audiobook
    case immersive

    var id: Self { self }

    var displayName: String {
        switch self {
        case .physical:
            return "Physical"
        case .ebook:
            return "Ebook"
        case .audiobook:
            return "Audiobook"
        case .immersive:
            return String(localized: "Immersive reading")
        }
    }
}
