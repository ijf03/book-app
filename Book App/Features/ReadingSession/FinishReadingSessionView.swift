//
//  FinishReadingSessionView.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct FinishReadingSessionView: View {

    @Environment(BookContentStore.self) private var contentStore: BookContentStore?
    @State private var noteDraft = ProgressNoteDraft()

    @Environment(ReadingSessionStore.self)
    private var sessionStore

    @Environment(\.dismiss)
    private var dismiss

    let book: Book
    let sessionID: UUID
    let onBookUpdated: (Book) -> Void
    let onSessionFinished: () -> Void

    @State private var progressModel: UpdateProgressViewModel

    init(
        book: Book,
        sessionID: UUID,
        onBookUpdated: @escaping (Book) -> Void,
        onSessionFinished: @escaping () -> Void
    ) {
        self.book = book
        self.sessionID = sessionID
        self.onBookUpdated = onBookUpdated
        self.onSessionFinished = onSessionFinished

        _progressModel = State(initialValue: UpdateProgressViewModel(book: book))
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.xl
            ) {

                sessionSummaryCard

                progressSection

                ProgressNoteSection(draft: noteDraft)

                actionButtons
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Finish Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var sessionSummaryCard: some View {
        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.md
            ) {

                Text("Session Duration")
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.textSecondary)

                ReadingDurationText(seconds: sessionDuration, defaultSize: 32)
                .foregroundStyle(Color.appAccent)
                .monospacedDigit()

                if let session =
                    sessionStore.session(
                        id: sessionID
                    )
                {
                    HStack {
                        Text(
                            timeString(
                                from: session.startedAt
                            )
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(
                            Color.textSecondary
                        )

                        Spacer()

                        if let endedAt =
                            session.endedAt
                        {
                            Text(
                                timeString(
                                    from: endedAt
                                )
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ProgressEntryFields(model: progressModel)
            if progressModel.hasPosition, let error = progressModel.validationMessage {
                Text(error).font(AppTypography.caption).foregroundStyle(Color.danger)
            }
            Text(progressModel.saveSummary).font(AppTypography.body)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(
            spacing: AppSpacing.sm
        ) {

            Button("Save Session") {
                saveSession()
            }
            .disabled(!noteDraft.canSave || !progressModel.canSaveSession)
            .accessibilityIdentifier("session.save")
            .buttonStyle(
                AppButtonStyle(
                    kind: .primary
                )
            )

            Button(
                "Discard Session",
                role: .destructive
            ) {
                discardSession()
            }
            .buttonStyle(
                AppButtonStyle(
                    kind: .secondary
                )
            )
        }
    }

    // MARK: - Helpers

    private func textFieldCard(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xs
                ) {
                    Text(title)
                        .font(
                            AppTypography.headline
                        )
                        .foregroundStyle(
                            Color.textPrimary
                        )

                    Text(subtitle)
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                }

                TextField(
                    placeholder,
                    text: text
                )
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var sessionDuration: Int {
        guard let session = sessionStore.session(id: sessionID) else { return 0 }
        return session.elapsedSeconds(at: session.endedAt ?? Date())
    }

    private func saveSession() {
        guard let updatedBook = progressModel.makeUpdatedBook(allowEmptyProgress: true) else { return }

        guard noteDraft.save(bookID: book.id, page: updatedBook.progress.page, to: contentStore) else { return }

        onBookUpdated(updatedBook)

        sessionStore.updateFinishedSessionProgress(
            sessionID: sessionID,
            progress: updatedBook.progress,
            format: updatedBook.format
        )

        dismiss()
        DispatchQueue.main.async {
            onSessionFinished()
        }
    }

    private func discardSession() {
        sessionStore.discardSession(
            id: sessionID
        )

        dismiss()
        DispatchQueue.main.async {
            onSessionFinished()
        }
    }

    private func timeString(
        from date: Date
    ) -> String {
        let formatter =
            DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func formatDuration(
        _ seconds: Int
    ) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }

    static func formatTimestamp(
        _ seconds: Int?
    ) -> String {
        guard let seconds else {
            return ""
        }

        return formatDuration(seconds)
    }

    static func parseTimestamp(
        _ value: String
    ) -> Int? {
        let parts =
            value.split(separator: ":")
                .compactMap {
                    Int($0)
                }

        guard parts.count == 3 else {
            return nil
        }

        return (parts[0] * 3600) +
            (parts[1] * 60) +
            parts[2]
    }
}
