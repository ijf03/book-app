//
//  DemoHomeView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct DemoHomeView: View {

    private let currentBook = Book.mockFourthWing

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xl
                ) {

                    greetingSection

                    checkInSection

                    currentlyReadingSection

                    upNextSection

                    recommendationSection
                }
                .padding(AppSpacing.md)
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("Home")
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {
            Text("Good afternoon")
                .font(AppTypography.body)
                .foregroundStyle(
                    Color.textSecondary
                )

            Text("What are you reading today?")
                .font(AppTypography.title)
                .foregroundStyle(
                    Color.textPrimary
                )
        }
    }

    // MARK: - Check In

    private var checkInSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Daily Check-In"
            )

            AppCard {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {

                    HStack {
                        Image(
                            systemName: "flame.fill"
                        )
                        .foregroundStyle(
                            Color.appAccent
                        )

                        VStack(
                            alignment: .leading,
                            spacing: AppSpacing.xs
                        ) {
                            Text("3 day reading streak")
                                .font(
                                    AppTypography.headline
                                )

                            Text(
                                "Read a little today to keep it going."
                            )
                            .font(
                                AppTypography.caption
                            )
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }

                        Spacer()
                    }

                    Button(
                        "Check In"
                    ) {
                        // Demo only
                    }
                    .buttonStyle(
                        AppButtonStyle(
                            kind: .primary
                        )
                    )
                }
            }
        }
    }

    // MARK: - Currently Reading

    private var currentlyReadingSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Currently Reading"
            )

            AppCard {
                HStack(
                    alignment: .top,
                    spacing: AppSpacing.md
                ) {

                    BookCoverView(
                        url: currentBook.coverURL
                    )
                    .frame(width: 90)

                    VStack(
                        alignment: .leading,
                        spacing: AppSpacing.sm
                    ) {

                        Text(currentBook.title)
                            .font(
                                AppTypography.headline
                            )

                        Text(
                            currentBook.authorText
                        )
                        .font(
                            AppTypography.body
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )

                        ProgressBar(
                            progress: 0.37
                        )

                        Text(
                            "184 of 498 pages · 37%"
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )

                        Button(
                            "Continue Reading"
                        ) {
                            // Demo only
                        }
                        .buttonStyle(
                            AppButtonStyle(
                                kind: .secondary
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Up Next

    private var upNextSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Up Next"
            )

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(
                    spacing: AppSpacing.md
                ) {

                    miniBookCard(
                        Book.mockTomorrow
                    )

                    miniBookCard(
                        Book.mockIronFlame
                    )

                    miniBookCard(
                        Book.mockSixOfCrows
                    )
                }
            }
        }
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Recommended for You"
            )

            AppCard {
                HStack(
                    spacing: AppSpacing.md
                ) {

                    BookCoverView(
                        url:
                            Book.mockCirce.coverURL
                    )
                    .frame(width: 70)

                    VStack(
                        alignment: .leading,
                        spacing: AppSpacing.xs
                    ) {

                        Text(
                            Book.mockCirce.title
                        )
                        .font(
                            AppTypography.headline
                        )

                        Text(
                            Book.mockCirce.authorText
                        )
                        .font(
                            AppTypography.body
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )

                        Text(
                            "Because you read fantasy and mythology."
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func miniBookCard(
        _ book: Book
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {

            BookCoverView(
                url: book.coverURL
            )
            .frame(
                width: 105
            )

            Text(book.title)
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textPrimary
                )
                .lineLimit(2)
                .frame(
                    width: 105,
                    alignment: .leading
                )
        }
    }
}
