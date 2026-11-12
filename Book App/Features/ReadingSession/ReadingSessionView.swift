//
//  ReadingSessionView.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import SwiftUI

struct ReadingSessionView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize = 44
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(ReadingSessionStore.self)
    private var sessionStore

    @Environment(\.dismiss)
    private var dismiss

    @Environment(LibraryStore.self) private var libraryStore: LibraryStore?

    let book: Book
    let onBookUpdated: (Book) -> Void

    @State
    private var sessionID: UUID?

    @State
    private var isShowingFinishSession =
        false

    var body: some View {
        ScrollView {
            VStack(
                spacing: AppSpacing.xl
            ) {

                bookSection

                timerSection

                actionSection
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Reading Session")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            beginSessionIfNeeded()
        }
        .onChange(of: libraryStore?.book(id: book.id)?.currentReadID) { _, newID in
            // Another device may have started a reread while this timer was open.
            if newID != book.currentReadID { dismiss() }
        }
        .navigationDestination(
            isPresented:
                $isShowingFinishSession
        ) {
            if let sessionID {
                FinishReadingSessionView(
                    book: book,
                    sessionID: sessionID,
                    onBookUpdated: {
                        updatedBook in
                        onBookUpdated(updatedBook)
                    },
                    onSessionFinished: {
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Book

    private var bookSection: some View {
        AppCard {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
                : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.md))
            layout {

                BookCoverView(
                    url: book.coverURL
                )
                .frame(width: 75)
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xs
                ) {
                    Text(book.title)
                        .font(
                            AppTypography.headline
                        )
                        .foregroundStyle(
                            Color.textPrimary
                        )

                    Text(book.authorText)
                        .font(
                            AppTypography.body
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )

                    statusChip
                }

                Spacer()
            }
        }
    }

    private var statusChip: some View {
        let paused = currentSession?.isPaused ?? false

        return Text(
            paused ? "Paused" : "Reading"
        )
        .font(AppTypography.caption)
        .foregroundStyle(
            paused
            ? Color.textPrimary
            : Color.appAccent
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    paused
                    ? Color.gray.opacity(0.18)
                    : Color.appAccent.opacity(0.14)
                )
        )
    }

    // MARK: - Timer

    private var timerSection: some View {
        AppCard {
            VStack(
                spacing: AppSpacing.md
            ) {

                Text(
                    currentSession?.isPaused == true
                    ? "SESSION PAUSED"
                    : "SESSION TIME"
                )
                .font(AppTypography.caption)
                .foregroundStyle(
                    currentSession?.isPaused == true
                    ? Color.textSecondary
                    : Color.appAccent
                )

                timerValue

                if let session = currentSession {

                    if session.isPaused {

                        if let pausedAt =
                            session.pausedAt
                        {
                            Text(
                                "Paused at \(timeString(from: pausedAt))"
                            )
                            .font(
                                AppTypography.caption
                            )
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }

                    } else {

                        Text(
                            "Started at \(timeString(from: session.startedAt))"
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                    }
                }
            }
            .frame(
                maxWidth: .infinity
            )
            .frame(
                minHeight: 170
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value:
                    currentSession?.isPaused
            )
        }
    }
    
    @ViewBuilder
    private var timerValue: some View {
        if let session = currentSession {
            if session.isPaused {
                ReadingDurationText(seconds: session.elapsedSeconds(at: session.pausedAt ?? Date()))
                    .foregroundStyle(Color.textPrimary)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ReadingDurationText(seconds: session.elapsedSeconds(at: context.date))
                        .foregroundStyle(Color.appAccent)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        } else {
            SwiftUI.ProgressView("Starting reading session")
        }
    }

    private func activeTimerCard(
        _ session: ReadingSession
    ) -> some View {
        AppCard {
            VStack(
                spacing: AppSpacing.md
            ) {
                Text("SESSION TIME")
                    .font(AppTypography.caption)
                    .foregroundStyle(
                        Color.textSecondary
                    )

                TimelineView(
                    .periodic(
                        from: .now,
                        by: 1
                    )
                ) {
                    context in
                    Text(
                        FinishReadingSessionView
                            .formatDuration(
                                session.elapsedSeconds(
                                    at: context.date
                                )
                            )
                    )
                    .font(
                        .system(
                            size: timerFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        Color.appAccent
                    )
                }

                Text(
                    "Started at \(timeString(from: session.startedAt))"
                )
                .font(AppTypography.caption)
                .foregroundStyle(
                    Color.textSecondary
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pausedTimerCard(
        _ session: ReadingSession
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 20
        )
        .fill(
            Color.gray.opacity(0.10)
        )
        .overlay {
            VStack(
                spacing: AppSpacing.md
            ) {
                Text("SESSION PAUSED")
                    .font(AppTypography.caption)
                    .foregroundStyle(
                        Color.textSecondary
                    )

                Text(
                    FinishReadingSessionView
                        .formatDuration(
                            session.elapsedSeconds(
                                at: session.pausedAt ?? Date()
                            )
                        )
                )
                .font(
                    .system(
                        size: timerFontSize,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    Color.textPrimary
                )

                if let pausedAt =
                    session.pausedAt
                {
                    Text(
                        "Paused at \(timeString(from: pausedAt))"
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }
            }
            .padding(AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
    }

    // MARK: - Actions

    private var actionSection: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AppSpacing.sm))
        return layout {

            if let session =
                currentSession
            {

                sessionToggleButton(
                    isPaused:
                        session.isPaused
                )

                endSessionButton
            }
        }
    }
    
    private func sessionToggleButton(
        isPaused: Bool
    ) -> some View {

        Button(
            isPaused
            ? "Resume Session"
            : "Pause Session"
        ) {
            if isPaused {
                resumeSession()
            } else {
                pauseSession()
            }
        }
        .font(
            AppTypography.headline
        )
        .foregroundStyle(
            isPaused
            ? Color.onAccent
            : Color.appAccent
        )
        .frame(
            maxWidth: .infinity
        )
        .frame(
            minHeight: 48
        )
        .background {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .fill(
                isPaused
                ? Color.appAccent
                : Color.surface
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .stroke(
                Color.appAccent,
                lineWidth: 1.5
            )
        }
    }
    
    private var endSessionButton:
        some View
    {
        Button(
            "End Session"
        ) {
            endSession()
        }
        .font(
            AppTypography.headline
        )
        .foregroundStyle(
            Color.danger
        )
        .frame(
            maxWidth: .infinity
        )
        .frame(
            minHeight: 48
        )
        .background {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .fill(
                Color.surface
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .stroke(
                Color.danger,
                lineWidth: 1.5
            )
        }
    }
    
    // MARK: - Session State

    private var currentSession:
        ReadingSession?
    {
        guard let sessionID else {
            return nil
        }

        return sessionStore.session(
            id: sessionID
        )
    }

    private func beginSessionIfNeeded() {
        guard sessionID == nil else {
            return
        }

        if let existing =
            sessionStore.ongoingSession(
                for: book.id, readID: book.currentReadID
            )
        {
            sessionID = existing.id
            return
        }

        let session =
            sessionStore.startSession(
                for: book
            )

        sessionID = session.id
    }

    private func pauseSession() {
        guard let sessionID else {
            return
        }

        sessionStore.pauseSession(
            id: sessionID
        )
    }

    private func resumeSession() {
        guard let sessionID else {
            return
        }

        sessionStore.resumeSession(
            id: sessionID
        )
    }

    private func endSession() {
        guard let sessionID else {
            return
        }

        sessionStore.endSession(
            id: sessionID,
            endProgress: book.progress
        )

        isShowingFinishSession = true
    }

    // MARK: - Helpers

    private func timeString(
        from date: Date
    ) -> String {
        let formatter =
            DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
