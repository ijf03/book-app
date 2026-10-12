//
//  HomeViewModel.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {

    private let store:
        LibraryStore

    private let sessionStore:
        ReadingSessionStore

    init(
        store: LibraryStore,
        sessionStore:
            ReadingSessionStore
    ) {
        self.store = store
        self.sessionStore = sessionStore
    }

    // MARK: - Books

    var currentlyReadingBooks:
        [Book]
    {
        store.books.filter {
            $0.status == .reading
        }
    }

    var upNextBooks:
        [Book]
    {
        store.books.filter {
            $0.status == .toRead
        }
    }

    var completedBooks:
        [Book]
    {
        store.books.filter {
            $0.status == .completed
        }
    }

    var readingCount: Int {
        currentlyReadingBooks.count
    }

    var toReadCount: Int {
        upNextBooks.count
    }

    var completedCount: Int {
        completedBooks.count
    }

    // MARK: - Reading Activity

    private var completedSessions:
        [ReadingSession]
    {
        sessionStore.sessions.filter {
            $0.endedAt != nil
        }
    }

    var todayReadingSeconds: Int {

        let calendar =
            Calendar.current

        return completedSessions
            .filter {
                session in

                guard let endedAt =
                    session.endedAt
                else {
                    return false
                }

                return calendar.isDateInToday(
                    endedAt
                )
            }
            .reduce(0) {
                total,
                session in

                total +
                    session.elapsedSeconds(
                        at:
                            session.endedAt ??
                            Date()
                    )
            }
    }

    var todaySessionCount: Int {

        let calendar =
            Calendar.current

        return completedSessions
            .filter {
                guard let endedAt =
                    $0.endedAt
                else {
                    return false
                }

                return calendar
                    .isDateInToday(
                        endedAt
                    )
            }
            .count
    }

    var currentStreak: Int {

        let calendar =
            Calendar.current

        let sessionDays: Set<Date> =
            Set(
                completedSessions
                    .compactMap {
                        session -> Date? in

                        guard let endedAt =
                            session.endedAt
                        else {
                            return nil
                        }

                        return calendar
                            .startOfDay(
                                for: endedAt
                            )
                    }
            )

        guard !sessionDays.isEmpty
        else {
            return 0
        }

        let today =
            calendar.startOfDay(
                for: Date()
            )

        guard let yesterday =
            calendar.date(
                byAdding: .day,
                value: -1,
                to: today
            )
        else {
            return 0
        }

        var day: Date

        if sessionDays.contains(today) {

            day = today

        } else if sessionDays.contains(
            yesterday
        ) {

            day = yesterday

        } else {

            return 0
        }

        var streak = 0

        while sessionDays.contains(
            day
        ) {

            streak += 1

            guard let previousDay =
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: day
                )
            else {
                break
            }

            day =
                previousDay
        }

        return streak
    }
    var formattedTodayReadingTime:
        String
    {
        formatDuration(
            todayReadingSeconds
        )
    }

    private func formatDuration(
        _ seconds: Int
    ) -> String {

        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes =
            seconds / 60

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours =
            minutes / 60

        let remainder =
            minutes % 60

        if remainder == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainder)m"
    }

    // MARK: - Library Actions

    func updateBook(
        _ updatedBook: Book
    ) {
        store.updateBook(
            updatedBook
        )
    }

    func removeBook(
        id: String
    ) {
        store.removeBook(
            id: id
        )
    }
}
