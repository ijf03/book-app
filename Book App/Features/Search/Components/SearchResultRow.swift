//
//  SearchResultRow.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import SwiftUI

struct SearchResultRow: View {

    let book: BookSearchResult
    let isAdded: Bool

    var body: some View {
        HStack(
            alignment: .top,
            spacing: AppSpacing.md
        ) {

            BookCoverView(
                url: book.coverURL
            )
            .frame(width: 56)

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
                    .lineLimit(2)

                Text(book.authorText)
                    .font(
                        AppTypography.body
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .lineLimit(2)

                if let pageCount =
                    book.pageCount
                {
                    Text(
                        "\(pageCount) pages"
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }

                if isAdded {
                    Label(
                        "In Library",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.appAccent
                    )
                }
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(
                Color.textSecondary
            )
        }
        .padding(
            .vertical,
            AppSpacing.sm
        )
    }
}
