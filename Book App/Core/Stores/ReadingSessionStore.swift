//
//  ReadingSessionStore.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class ReadingSessionStore {
    /// Hydration never saves back to the repository, avoiding listener feedback.
    func reloadFromLocalSync() {
        do {
            sessions = try localDataSource.loadSessions()
            persistenceError = nil
        } catch { persistenceError = SyncFailure.localStorage.message }
    }

    func clearAccountMemory() { sessions = []; persistenceError = nil }


    private(set) var sessions:
        [ReadingSession]

    private let localDataSource:
        LocalReadingSessionDataSource

    private(set) var persistenceError:
        String?

    init(
        sessions: [ReadingSession],
        localDataSource:
            LocalReadingSessionDataSource
    ) {
        self.sessions = sessions
        self.localDataSource = localDataSource
    }

    // MARK: - Start

    @discardableResult
    func startSession(
        for book: Book
    ) -> ReadingSession {

        if let existing =
            ongoingSession(
                for: book.id, readID: book.currentReadID
            )
        {
            return existing
        }

        var session =
            ReadingSession(
                bookID: book.id,
                startProgress: book.progress,
                readID: book.currentReadID
            )

        session.formats = [book.format]
        sessions.append(session)
        save()

        return session
    }

    // MARK: - Pause / Resume

    func pauseSession(
        id: UUID
    ) {
        guard let index =
            sessions.firstIndex(
                where: { $0.id == id }
            )
        else {
            return
        }

        guard sessions[index].endedAt == nil,
              sessions[index].pausedAt == nil
        else {
            return
        }

        sessions[index].pausedAt = Date()
        save()
    }

    func resumeSession(
        id: UUID
    ) {
        guard let index =
            sessions.firstIndex(
                where: { $0.id == id }
            ),
            let pausedAt =
                sessions[index].pausedAt
        else {
            return
        }

        let pausedSeconds =
            Int(
                Date().timeIntervalSince(
                    pausedAt
                )
            )

        sessions[index].totalPausedSeconds +=
            max(0, pausedSeconds)

        sessions[index].pausedAt = nil
        save()
    }

    // MARK: - End

    func endSession(
        id: UUID,
        endProgress: ReadingProgress
    ) {
        guard let index =
            sessions.firstIndex(
                where: { $0.id == id }
            )
        else {
            return
        }

        guard sessions[index].endedAt == nil
        else {
            return
        }

        if let pausedAt =
            sessions[index].pausedAt
        {
            let pausedSeconds =
                Int(
                    Date().timeIntervalSince(
                        pausedAt
                    )
                )

            sessions[index].totalPausedSeconds +=
                max(0, pausedSeconds)

            sessions[index].pausedAt = nil
        }

        sessions[index].endedAt = Date()
        sessions[index].endProgress =
            endProgress

        save()
    }

    func updateFinishedSessionProgress(
        sessionID: UUID,
        progress: ReadingProgress,
        format: ReadingFormat? = nil
    ) {
        guard let index =
            sessions.firstIndex(
                where: { $0.id == sessionID }
            )
        else {
            return
        }

        sessions[index].endProgress = progress
        if let format {
            sessions[index].formats = ReadingFormat.allCases.filter {
                Set((sessions[index].formats ?? []) + [format]).contains($0)
            }
        }
        save()
    }

    func discardSession(
        id: UUID
    ) {
        sessions.removeAll {
            $0.id == id
        }

        save()
    }

    // MARK: - Lookup

    func session(
        id: UUID
    ) -> ReadingSession? {
        sessions.first {
            $0.id == id
        }
    }

    func ongoingSession(
        for bookID: String, readID: String? = nil
    ) -> ReadingSession? {
        sessions.first {
            $0.bookID == bookID && $0.readID == readID &&
            $0.endedAt == nil
        }
    }

    func sessions(
        for bookID: String
    ) -> [ReadingSession] {
        sessions.filter {
            $0.bookID == bookID
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            try localDataSource
                .saveSessions(sessions)

            persistenceError = nil

        } catch {
            persistenceError =
                error.localizedDescription
        }
    }
}
