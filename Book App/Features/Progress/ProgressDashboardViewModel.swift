//
//  ProgressDashboardViewModel.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProgressDashboardViewModel {

    private let libraryStore:
        LibraryStore

    private let sessionStore:
        ReadingSessionStore

    init(
        libraryStore: LibraryStore,
        sessionStore: ReadingSessionStore
    ) {
        self.libraryStore =
            libraryStore

        self.sessionStore =
            sessionStore
    }

    // MARK: - Sessions

    var completedSessions:
        [ReadingSession]
    {
        sessionStore.sessions
            .filter {
                $0.endedAt != nil
            }
            .sorted {
                ($0.endedAt ?? .distantPast) >
                ($1.endedAt ?? .distantPast)
            }
    }

    var totalSessionCount: Int {
        completedSessions.count
    }

    var totalReadingSeconds: Int {
        completedSessions.reduce(0) {
            partialResult,
            session in

            partialResult +
                session.elapsedSeconds(
                    at:
                        session.endedAt ??
                        Date()
                )
        }
    }

    // MARK: - Books

    var completedBookCount: Int {
        libraryStore.books
            .filter {
                $0.status == .completed
            }
            .count
    }

    // MARK: - Pages

    var totalPagesRead: Int {

        completedSessions.reduce(0) {
            total,
            session in

            guard
                let startPage =
                    session
                        .startProgress
                        .page,
                let endPage =
                    session
                        .endProgress?
                        .page
            else {
                return total
            }

            return total +
                max(
                    0,
                    endPage - startPage
                )
        }
    }

    // MARK: - Average

    var averageSessionSeconds: Int {

        guard !completedSessions
            .isEmpty
        else {
            return 0
        }

        return totalReadingSeconds /
            completedSessions.count
    }

    // MARK: - Recent Sessions

    var recentSessions:
        [ReadingSession]
    {
        Array(
            completedSessions
                .prefix(5)
        )
    }

    // MARK: - Streak

    var currentStreak: Int {

        let calendar =
            Calendar.current

        let sessionDays =
            Set(
                completedSessions.map {
                    calendar.startOfDay(
                        for:
                            $0.endedAt ??
                            $0.startedAt
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

        let yesterday =
            calendar.date(
                byAdding: .day,
                value: -1,
                to: today
            )!

        var currentDay: Date

        if sessionDays.contains(today) {
            currentDay = today
        } else if sessionDays.contains(
            yesterday
        ) {
            currentDay = yesterday
        } else {
            return 0
        }

        var streak = 0

        while sessionDays.contains(
            currentDay
        ) {
            streak += 1

            guard let previousDay =
                calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: currentDay
                )
            else {
                break
            }

            currentDay =
                previousDay
        }

        return streak
    }

    // MARK: - Weekly Activity

    var weeklyActivity:
        [DailyReadingActivity]
    {
        let calendar =
            Calendar.current

        let today =
            calendar.startOfDay(
                for: Date()
            )

        return (0..<7)
            .reversed()
            .compactMap {
                offset in

                guard let date =
                    calendar.date(
                        byAdding: .day,
                        value: -offset,
                        to: today
                    )
                else {
                    return nil
                }

                let seconds =
                    completedSessions
                        .filter {
                            session in

                            guard let endDate =
                                session.endedAt
                            else {
                                return false
                            }

                            return calendar
                                .isDate(
                                    endDate,
                                    inSameDayAs:
                                        date
                                )
                        }
                        .reduce(0) {
                            $0 +
                            $1.elapsedSeconds(
                                at:
                                    $1.endedAt ??
                                    Date()
                            )
                        }

                return DailyReadingActivity(
                    date: date,
                    seconds: seconds
                )
            }
    }

    // MARK: - Book Lookup

    func book(
        for session:
            ReadingSession
    ) -> Book? {

        libraryStore.books.first {
            $0.id ==
                session.bookID
        }
    }

    // MARK: - Formatting

    func formattedReadingTime(
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

        let remainingMinutes =
            minutes % 60

        if remainingMinutes == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainingMinutes)m"
    }
}

struct DailyReadingActivity:
    Identifiable,
    Hashable
{
    let date: Date
    let seconds: Int

    var id: Date {
        date
    }
}
