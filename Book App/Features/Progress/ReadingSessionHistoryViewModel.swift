//
//  ReadingSessionHistoryViewModel.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ReadingSessionHistoryViewModel {

    private let libraryStore:
        LibraryStore

    private let sessionStore:
        ReadingSessionStore

    init(
        libraryStore: LibraryStore,
        sessionStore:
            ReadingSessionStore
    ) {
        self.libraryStore =
            libraryStore

        self.sessionStore =
            sessionStore
    }

    var sessions:
        [ReadingSession]
    {
        sessionStore.sessions
            .filter {
                $0.endedAt != nil
            }
            .sorted {
                ($0.endedAt ?? .distantPast)
                    >
                ($1.endedAt ?? .distantPast)
            }
    }

    var groupedSessions:
        [ReadingSessionDayGroup]
    {
        let calendar =
            Calendar.current

        let groups =
            Dictionary(
                grouping: sessions
            ) {
                session in

                calendar.startOfDay(
                    for:
                        session.endedAt ??
                        session.startedAt
                )
            }

        return groups
            .map {
                date,
                sessions in

                ReadingSessionDayGroup(
                    date: date,
                    sessions:
                        sessions.sorted {
                            ($0.endedAt ??
                                .distantPast)
                            >
                            ($1.endedAt ??
                                .distantPast)
                        }
                )
            }
            .sorted {
                $0.date >
                $1.date
            }
    }

    func book(
        for session:
            ReadingSession
    ) -> Book? {

        libraryStore.books
            .first {
                $0.id ==
                    session.bookID
            }
    }

    func durationText(
        for session:
            ReadingSession
    ) -> String {

        let seconds =
            session.elapsedSeconds(
                at:
                    session.endedAt ??
                    Date()
            )

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

        let remaining =
            minutes % 60

        if remaining == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remaining)m"
    }

    func timeText(
        for session:
            ReadingSession
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.timeStyle =
            .short

        return formatter.string(
            from:
                session.endedAt ??
                session.startedAt
        )
    }

    func progressText(
        for session:
            ReadingSession
    ) -> String? {

        if
            let start =
                session
                    .startProgress
                    .page,
            let end =
                session
                    .endProgress?
                    .page
        {
            let difference =
                max(
                    0,
                    end - start
                )

            return
                "Page \(start) → \(end) · \(difference) pages"
        }

        if
            let start =
                session
                    .startProgress
                    .percentage,
            let end =
                session
                    .endProgress?
                    .percentage
        {
            return
                "\(formatPercentage(start)) → \(formatPercentage(end))"
        }

        if
            let start =
                session
                    .startProgress
                    .timestampSeconds,
            let end =
                session
                    .endProgress?
                    .timestampSeconds
        {
            return
                "\(formatTimestamp(start)) → \(formatTimestamp(end))"
        }

        return nil
    }

    private func formatPercentage(
        _ value: Double
    ) -> String {

        if value.rounded() == value {
            return "\(Int(value))%"
        }

        return String(
            format: "%.1f%%",
            value
        )
    }

    private func formatTimestamp(
        _ seconds: Int
    ) -> String {

        let hours =
            seconds / 3600

        let minutes =
            (seconds % 3600) / 60

        let remaining =
            seconds % 60

        return String(
            format:
                "%02d:%02d:%02d",
            hours,
            minutes,
            remaining
        )
    }
}

struct ReadingSessionDayGroup:
    Identifiable
{
    let date: Date
    let sessions:
        [ReadingSession]

    var id: Date {
        date
    }
}
