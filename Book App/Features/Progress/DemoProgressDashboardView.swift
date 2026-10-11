//
//  DemoProgressDashboardView.swift
//  Book App
//
//  Created by Sabi on 10/10/2026.
//

import SwiftUI

struct DemoProgressDashboardView: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xl
                ) {

                    overviewSection

                    goalSection

                    readingActivitySection

                    formatSection

                    completedSection
                }
                .padding(AppSpacing.md)
            }
            .background(
                Color.surfaceSecondary
            )
            .navigationTitle(
                "Stats & Goals"
            )
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "This Month"
            )

            HStack(
                spacing: AppSpacing.md
            ) {

                statCard(
                    value: "4",
                    title: "Books"
                )

                statCard(
                    value: "1,248",
                    title: "Pages"
                )

                statCard(
                    value: "9h 42m",
                    title: "Reading"
                )
            }
        }
    }

    // MARK: - Goal

    private var goalSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Reading Goal"
            )

            AppCard {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: AppSpacing.xs
                        ) {
                            Text(
                                "2026 Reading Goal"
                            )
                            .font(
                                AppTypography.headline
                            )

                            Text(
                                "18 of 30 books"
                            )
                            .font(
                                AppTypography.body
                            )
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }

                        Spacer()

                        Text("60%")
                            .font(
                                AppTypography.headline
                            )
                            .foregroundStyle(
                                Color.appAccent
                            )
                    }

                    ProgressBar(
                        progress: 0.60
                    )
                }
            }
        }
    }

    // MARK: - Activity

    private var readingActivitySection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Reading Activity"
            )

            AppCard {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.md
                ) {

                    Text(
                        "Last 7 Days"
                    )
                    .font(
                        AppTypography.headline
                    )

                    HStack(
                        alignment: .bottom,
                        spacing: AppSpacing.sm
                    ) {

                        dayBar(
                            "M",
                            value: 0.3
                        )

                        dayBar(
                            "T",
                            value: 0.55
                        )

                        dayBar(
                            "W",
                            value: 0.8
                        )

                        dayBar(
                            "T",
                            value: 0.45
                        )

                        dayBar(
                            "F",
                            value: 0.9
                        )

                        dayBar(
                            "S",
                            value: 0.65
                        )

                        dayBar(
                            "S",
                            value: 0.4
                        )
                    }
                    .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Format

    private var formatSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Reading by Format"
            )

            AppCard {
                VStack(
                    spacing: AppSpacing.md
                ) {

                    formatRow(
                        name: "Physical",
                        amount: "46%",
                        icon: "book.closed"
                    )

                    Divider()

                    formatRow(
                        name: "Ebook",
                        amount: "34%",
                        icon: "ipad"
                    )

                    Divider()

                    formatRow(
                        name: "Audiobook",
                        amount: "20%",
                        icon: "headphones"
                    )
                }
            }
        }
    }

    // MARK: - Completed

    private var completedSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Recently Completed"
            )

            AppCard {
                HStack(
                    spacing: AppSpacing.md
                ) {

                    BookCoverView(
                        url:
                            Book
                                .mockProjectHailMary
                                .coverURL
                    )
                    .frame(width: 65)

                    VStack(
                        alignment: .leading,
                        spacing: AppSpacing.xs
                    ) {

                        Text(
                            Book
                                .mockProjectHailMary
                                .title
                        )
                        .font(
                            AppTypography.headline
                        )

                        Text(
                            Book
                                .mockProjectHailMary
                                .authorText
                        )
                        .font(
                            AppTypography.body
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )

                        Label(
                            "Completed this month",
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

                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func statCard(
        value: String,
        title: String
    ) -> some View {

        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.xs
            ) {

                Text(value)
                    .font(
                        AppTypography.headline
                    )
                    .foregroundStyle(
                        Color.textPrimary
                    )

                Text(title)
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }

    private func dayBar(
        _ day: String,
        value: Double
    ) -> some View {

        VStack {
            Spacer()

            RoundedRectangle(
                cornerRadius: 5
            )
            .fill(
                Color.appAccent
            )
            .frame(
                height:
                    max(
                        10,
                        90 * value
                    )
            )

            Text(day)
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private func formatRow(
        name: String,
        amount: String,
        icon: String
    ) -> some View {

        HStack {

            Image(
                systemName: icon
            )
            .frame(width: 24)
            .foregroundStyle(
                Color.appAccent
            )

            Text(name)
                .font(
                    AppTypography.body
                )

            Spacer()

            Text(amount)
                .font(
                    AppTypography.headline
                )
        }
    }
}
