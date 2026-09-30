//
//  BookShelfItem.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookShelfItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            BookCoverView(url: book.coverURL)
                .frame(width: 110)

            Text(book.title)
                .font(AppTypography.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)

            Text(book.authorText)
                .font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 110, alignment: .leading)
    }
}

#Preview {
    BookShelfItem(book: .mockTomorrow)
        .padding()
}
