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
        libraryStore.books.reduce(0) { $0 + $1.completedReadCount }
    }

    // MARK: - Pages

    private(set) var totalPagesRead = 0

    func refreshRecordedPages() async {
        let input = StatisticsInput(books: [], sessions: sessionStore.sessions, reviews: [])
        let now = Date()
        let calendar = Calendar.current
        let task = Task.detached(priority: .userInitiated) {
            ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now).pages
        }
        let pages = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        guard !Task.isCancelled, libraryStore.accountScope?.isActive != false else { return }
        totalPagesRead = pages
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
        let calendar = Calendar.current, now = Date()
        let events = completedSessions.compactMap { session -> ReadingStatistics.SessionEvent? in
            guard let end = session.endedAt, end <= now, end >= session.startedAt,
                  session.totalPausedSeconds >= 0 else { return nil }
            return .init(id: session.id, bookID: session.bookID, start: session.startedAt, end: end,
                         seconds: session.elapsedSeconds(at: end), pages: nil)
        }
        return ReadingDayCalculator.currentStreak(
            days: ReadingDayCalculator.days(events: events, checkIns: libraryStore.checkIns.entries, calendar: calendar, now: now),
            calendar: calendar, now: now)
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
