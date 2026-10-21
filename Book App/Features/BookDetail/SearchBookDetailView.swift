//
//  SearchBookDetailView.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import SwiftUI

struct SearchBookDetailView: View {

    let book: BookSearchResult
    let libraryStore: LibraryStore

    @State
    private var isShowingAddSheet = false

    @State
    private var wasJustAdded = false

    private var isAlreadyAdded: Bool {
        libraryStore.contains(
            bookID: book.id
        )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.xl
            ) {

                header

                addSection

                metadataSection

                if let description =
                    book.description
                {
                    aboutSection(
                        description
                    )
                }
            }
            .padding(
                AppSpacing.md
            )
        }
        .background(
            Color.surfaceSecondary
        )
        .navigationTitle(
            "Book Details"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .sheet(
            isPresented:
                $isShowingAddSheet
        ) {
            AddBookSheet(
                book: book
            ) {
                status,
                format in

                addBook(
                    status: status,
                    format: format
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            spacing: AppSpacing.md
        ) {
            BookCoverView(
                url: book.coverURL
            )
            .frame(
                width: 150
            )

            VStack(
                spacing: AppSpacing.sm
            ) {
                Text(book.title)
                    .font(
                        AppTypography.title
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )
                    .multilineTextAlignment(
                        .center
                    )

                Text(book.authorText)
                    .font(
                        AppTypography.body
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
            }
        }
        .frame(
            maxWidth: .infinity
        )
    }

    // MARK: - Add

    private var addSection: some View {
        VStack(
            spacing: AppSpacing.sm
        ) {

            if isAlreadyAdded ||
                wasJustAdded
            {
                Label(
                    "Added to Library",
                    systemImage:
                        "checkmark.circle.fill"
                )
                .font(
                    AppTypography.headline
                )
                .foregroundStyle(
                    Color.appAccent
                )
                .frame(
                    maxWidth: .infinity
                )

            } else {
                Button(
                    "Add to Library"
                ) {
                    isShowingAddSheet =
                        true
                }
                .buttonStyle(
                    AppButtonStyle(
                        kind: .primary
                    )
                )
            }
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataSection:
        some View
    {
        if let pageCount =
            book.pageCount
        {
            AppCard {
                HStack {
                    Image(
                        systemName:
                            "book.pages"
                    )
                    .foregroundStyle(
                        Color.appAccent
                    )

                    Text(
                        "\(pageCount) pages"
                    )
                    .font(
                        AppTypography.body
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )

                    Spacer()
                }
            }
        }
    }

    // MARK: - About

    private func aboutSection(
        _ description: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            SectionHeader(
                title: "About"
            )

            Text(description)
                .font(
                    AppTypography.body
                )
                .foregroundStyle(
                    Color.textPrimary
                )
        }
    }

    // MARK: - Add Book

    private func addBook(
        status: ReadingStatus,
        format: ReadingFormat
    ) -> Bool {
        guard !isAlreadyAdded else { return true }

        let newBook = BookFactory.makeBook(
            from: book,
            status: status,
            format: format
        )
        let didAdd = libraryStore.addBook(newBook)
        if didAdd { wasJustAdded = true }
        return didAdd
    }
}
