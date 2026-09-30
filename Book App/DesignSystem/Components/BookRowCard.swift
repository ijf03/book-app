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
        HStack(alignment: .top, spacing: AppSpacing.md) {
            BookCoverView(url: book.coverURL)
                .frame(width: 72)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(book.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)

                Text(book.authorText)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(book.status.displayName)
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.appAccent)
            }

            Spacer()
        }
        .frame(minHeight: 108)
    }
}

#Preview {
    AppCard {
        BookRowCard(book: .mockFourthWing)
    }
    .padding()
}
