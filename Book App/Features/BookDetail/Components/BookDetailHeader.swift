//
//  BookDetailHeader.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailHeader: View {
    let book: Book

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            BookCoverView(url: book.coverURL)
                .frame(width: 150)

            VStack(spacing: AppSpacing.sm) {
                Text(book.title)
                    .font(AppTypography.title)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(book.authorText)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: AppSpacing.sm) {
                    Text(book.status.displayName)

                    Text("•")

                    Text(book.format.displayName)
                }
                .font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary)

                if let pageCount = book.pageCount {
                    Text("\(pageCount) pages")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BookDetailHeader(book: .mockFourthWing)
        .padding()
}
