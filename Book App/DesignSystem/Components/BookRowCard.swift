//
//  BookRowCard.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookRowCard: View {
    let book: Book

    var body: some View {
        HStack(
            alignment: .top,
            spacing: AppSpacing.md
        ) {
            BookCoverView(
                url: book.coverURL
            )
            .frame(width: 72)

            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {
                Text(book.title)
                    .font(
                        AppTypography.headline
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )
                    .lineLimit(2)

                Text(book.authorText)
                    .font(AppTypography.body)
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .lineLimit(1)

                Spacer()

                if book.status == .reading {
                    readingProgress
                } else {
                    Text(
                        book.status.displayName
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }
            }

            Spacer()
        }
        .frame(minHeight: 108)
    }

    private var readingProgress:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {
            ProgressBar(
                progress: progressFraction
            )

            Text(progressText)
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )
        }
    }

    private var progressFraction: Double {
        if
            let percentage =
                book.progress.percentage
        {
            return min(
                max(
                    percentage / 100,
                    0
                ),
                1
            )
        }

        if
            let page =
                book.progress.page,
            let pageCount =
                book.pageCount,
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

    private var progressText: String {
        if
            let percentage =
                book.progress.percentage
        {
            let value =
                percentage.rounded() ==
                    percentage
                ? String(Int(percentage))
                : String(
                    format: "%.1f",
                    percentage
                )

            return "\(value)% complete"
        }

        if
            let page =
                book.progress.page,
            let pageCount =
                book.pageCount
        {
            return
                "Page \(page) of \(pageCount)"
        }

        return "Reading"
    }
}

#Preview {
    AppCard {
        BookRowCard(
            book: .mockFourthWing
        )
    }
    .padding()
}
