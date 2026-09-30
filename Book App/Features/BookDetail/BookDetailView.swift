//
//  BookDetailView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailView: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                BookCoverView(url: book.coverURL)
                    .frame(width: 160)

                VStack(spacing: AppSpacing.sm) {
                    Text(book.title)
                        .font(AppTypography.title)
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(book.authorText)
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textSecondary)

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

                if let description = book.description {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "About")

                        Text(description)
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppSpacing.md)
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: .mockFourthWing)
    }
}
