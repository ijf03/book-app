//
//  ReadingStatus.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case reading
    case toRead
    case completed
    case abandoned

    var id: Self { self }

    var displayName: String {
        switch self {
        case .reading:
            return "Reading"
        case .toRead:
            return "To Read"
        case .abandoned:
            return "Did not finish"
        case .completed:
            return "Completed"
        }
    }
}
