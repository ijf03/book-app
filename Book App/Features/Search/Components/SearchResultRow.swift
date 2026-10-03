//
//  SearchResultRow.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import SwiftUI

struct SearchResultRow: View {

    let book: BookSearchResult

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

                if let pageCount = book.pageCount {
                    Text("\(pageCount) pages")
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
        .padding(.vertical, AppSpacing.sm)
    }
}
