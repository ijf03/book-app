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

    @State
    private var pageText: String

    @State
    private var percentageText: String

    @State
    private var timestampText: String

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

        _pageText = State(
            initialValue:
                book.progress.page.map(String.init) ?? ""
        )

        _percentageText = State(
            initialValue:
                book.progress.percentage.map {
                    String(Int($0.rounded()))
                } ?? ""
        )

        _timestampText = State(
            initialValue:
                Self.formatTimestamp(
                    book.progress.timestampSeconds
                )
        )
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

                Text(
                    formattedSessionDuration
                )
                .font(
                    .system(
                        size: 32,
                        weight: .semibold,
                        design: .rounded
                    )
                )
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
        VStack(
            alignment: .leading,
            spacing: AppSpacing.md
        ) {

            SectionHeader(
                title: "Progress After Session"
            )

            VStack(
                spacing: AppSpacing.md
            ) {
                textFieldCard(
                    title: "Page",
                    subtitle: "Optional · physical / ebook",
                    text: $pageText,
                    placeholder: "214"
                )
                .keyboardType(.numberPad)

                textFieldCard(
                    title: "Percentage",
                    subtitle: "Optional · works with any format",
                    text: $percentageText,
                    placeholder: "67"
                )
                .keyboardType(.decimalPad)

                textFieldCard(
                    title: "Timestamp",
                    subtitle: "Optional · HH:MM:SS for audio",
                    text: $timestampText,
                    placeholder: "01:42:18"
                )
            }
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
            .disabled(!noteDraft.canSave)
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

    private var formattedSessionDuration: String {
        guard let session =
            sessionStore.session(
                id: sessionID
            )
        else {
            return "00:00:00"
        }

        return Self.formatDuration(
            session.elapsedSeconds(
                at: session.endedAt ?? Date()
            )
        )
    }

    private func saveSession() {
        var updatedBook = book

        updatedBook.progress = ReadingProgress(
            page: pageText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
                ? nil
                : Int(pageText),
            percentage: percentageText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
                ? nil
                : Double(percentageText),
            timestampSeconds: timestampText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
                ? nil
                : Self.parseTimestamp(
                    timestampText
                )
        )

        guard noteDraft.save(bookID: book.id, page: updatedBook.progress.page, to: contentStore) else { return }

        onBookUpdated(updatedBook)

        sessionStore.updateFinishedSessionProgress(
            sessionID: sessionID,
            progress: updatedBook.progress
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
