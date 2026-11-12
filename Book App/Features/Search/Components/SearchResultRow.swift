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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.md))
        return layout {

            BookCoverView(
                url: book.coverURL
            )
            .frame(width: 56)
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
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)

                Text(book.authorText)
                    .font(
                        AppTypography.body
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)

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

                if !book.genreChips.isEmpty {
                    Text(book.genreChips.formatted()).font(AppTypography.caption)
                        .foregroundStyle(Color.appAccent).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }
                Text("View synopsis & editions").font(AppTypography.caption)
                    .foregroundStyle(Color.textSecondary)

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
