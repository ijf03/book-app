//
//  ReadingSession.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import Foundation

struct ReadingSession:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    let id: UUID
    let bookID: String

    let startedAt: Date
    var endedAt: Date?

    var pausedAt: Date?
    var totalPausedSeconds: Int

    let startProgress: ReadingProgress
    var endProgress: ReadingProgress?

    init(
        id: UUID = UUID(),
        bookID: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        pausedAt: Date? = nil,
        totalPausedSeconds: Int = 0,
        startProgress: ReadingProgress,
        endProgress: ReadingProgress? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.pausedAt = pausedAt
        self.totalPausedSeconds = totalPausedSeconds
        self.startProgress = startProgress
        self.endProgress = endProgress
    }

    var isPaused: Bool {
        pausedAt != nil && endedAt == nil
    }

    var isActive: Bool {
        endedAt == nil
    }

    func elapsedSeconds(
        at now: Date = Date()
    ) -> Int {
        let endReference =
            endedAt ?? now

        var total =
            Int(
                endReference.timeIntervalSince(
                    startedAt
                )
            ) - totalPausedSeconds

        if let pausedAt,
           endedAt == nil
        {
            total -= Int(
                now.timeIntervalSince(
                    pausedAt
                )
            )
        }

        return max(0, total)
    }
}
