//
//  BookStatusCard.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookStatusCard: View {
    let book: Book
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    var body: some View {
        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.md
            ) {
                Text(statusHeading)
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.textPrimary)

                statusContent

                Button(primaryActionTitle) {
                    primaryAction()
                }
                .buttonStyle(
                    AppButtonStyle(kind: .primary)
                )

                if let secondaryAction {
                    Button("Update Progress") {
                        secondaryAction()
                    }
                    .buttonStyle(
                        AppButtonStyle(
                            kind: .secondary
                        )
                    )
                }
            }
        }
    }

    private var statusHeading: String {
        switch book.status {
        case .reading:
            return "Reading Progress"

        case .toRead:
            return "Ready to Read"

        case .completed:
            return "Finished"
        case .abandoned:
            return "Did not finish"
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch book.status {

        case .reading, .abandoned:
            readingProgress

        case .toRead:
            Text(
                "Start reading when you're ready."
            )
            .font(AppTypography.body)
            .foregroundStyle(Color.textSecondary)

        case .completed:
            Text(
                "You've finished this book."
            )
            .font(AppTypography.body)
            .foregroundStyle(Color.textSecondary)
        }
    }

    private var readingProgress: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            ProgressBar(
                progress: progressFraction
            )

            Text(progressDescription)
                .font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var progressFraction: Double {
        if let percentage = book.progress.percentage {
            return min(
                max(percentage / 100, 0),
                1
            )
        }

        if
            let page = book.progress.page,
            let pageCount = book.pageCount,
            pageCount > 0
        {
            return min(
                max(
                    Double(page) /
                    Double(pageCount),
                    0
                ),
                1
            )
        }

        return 0
    }

    private var progressDescription: String {
        var parts: [String] = []

        if let page = book.progress.page {
            if let pageCount = book.pageCount {
                parts.append(
                    "Page \(page) of \(pageCount)"
                )
            } else {
                parts.append(
                    "Page \(page)"
                )
            }
        }

        if let percentage = book.progress.percentage {
            let value =
                percentage.rounded() == percentage
                ? String(Int(percentage))
                : String(
                    format: "%.1f",
                    percentage
                )

            parts.append("\(value)%")
        }

        if
            let seconds =
                book.progress.timestampSeconds
        {
            parts.append(
                formattedTimestamp(seconds)
            )
        }

        if parts.isEmpty {
            return "No progress recorded yet"
        }

        return parts.joined(
            separator: " · "
        )
    }

    private func formattedTimestamp(
        _ seconds: Int
    ) -> String {
        let hours = seconds / 3600
        let minutes =
            (seconds % 3600) / 60
        let remaining =
            seconds % 60

        return String(
            format: "%02d:%02d:%02d",
            hours,
            minutes,
            remaining
        )
    }
}
