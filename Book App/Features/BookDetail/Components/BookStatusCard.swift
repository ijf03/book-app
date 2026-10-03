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
                        AppButtonStyle(kind: .secondary)
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
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch book.status {
        case .reading:
            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {
                Text(
                    "Progress tracking will appear here."
                )
                .font(AppTypography.body)
                .foregroundStyle(Color.textSecondary)

                ProgressBar(progress: 0)
            }

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
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        BookStatusCard(
            book: .mockFourthWing,
            primaryActionTitle: "Start a Reading Session",
            primaryAction: {},
            secondaryAction: {}
        )

        BookStatusCard(
            book: .mockTomorrow,
            primaryActionTitle: "Start Reading",
            primaryAction: {},
            secondaryAction: nil
        )
    }
    .padding()
}
