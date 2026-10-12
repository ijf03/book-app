//
//  ReadingSessionHistoryView.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct ReadingSessionHistoryView: View {

    @State
    private var viewModel:
        ReadingSessionHistoryViewModel

    init(
        libraryStore: LibraryStore,
        sessionStore:
            ReadingSessionStore
    ) {
        _viewModel =
            State(
                initialValue:
                    ReadingSessionHistoryViewModel(
                        libraryStore:
                            libraryStore,
                        sessionStore:
                            sessionStore
                    )
            )
    }

    var body: some View {

        ScrollView {

            if viewModel
                .sessions
                .isEmpty
            {
                emptyState

            } else {

                LazyVStack(
                    alignment: .leading,
                    spacing: AppSpacing.lg
                ) {

                    ForEach(
                        viewModel
                            .groupedSessions
                    ) { group in

                        sessionGroup(
                            group
                        )
                    }
                }
                .padding(
                    AppSpacing.md
                )
            }
        }
        .background(
            Color.surfaceSecondary
        )
        .navigationTitle(
            "Reading History"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    // MARK: - Group

    private func sessionGroup(
        _ group:
            ReadingSessionDayGroup
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            Text(
                sectionDate(
                    group.date
                )
            )
            .font(
                AppTypography.headline
            )
            .foregroundStyle(
                Color.textSecondary
            )

            AppCard {

                VStack(
                    spacing: 0
                ) {

                    ForEach(
                        Array(
                            group
                                .sessions
                                .enumerated()
                        ),
                        id:
                            \.element.id
                    ) {
                        index,
                        session in

                        sessionRow(
                            session
                        )

                        if index <
                            group
                                .sessions
                                .count - 1
                        {
                            Divider()
                                .padding(
                                    .leading,
                                    56
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func sessionRow(
        _ session:
            ReadingSession
    ) -> some View {

        let book =
            viewModel.book(
                for: session
            )

        return HStack(
            alignment: .center,
            spacing: AppSpacing.md
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius:
                        AppRadius.sm,
                    style:
                        .continuous
                )
                .fill(
                    Color.accentTint
                )

                Image(
                    systemName:
                        "book.open"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.appAccent
                )
            }
            .frame(
                width: 42,
                height: 42
            )

            VStack(
                alignment: .leading,
                spacing: AppSpacing.xs
            ) {

                Text(
                    book?.title ??
                    "Reading Session"
                )
                .font(
                    AppTypography.headline
                )
                .foregroundStyle(
                    Color.textPrimary
                )
                .lineLimit(2)

                HStack(
                    spacing: AppSpacing.xs
                ) {

                    Text(
                        viewModel
                            .timeText(
                                for: session
                            )
                    )

                    Text("·")

                    Text(
                        viewModel
                            .durationText(
                                for: session
                            )
                    )
                }
                .font(
                    AppTypography.caption
                )
                .foregroundStyle(
                    Color.textSecondary
                )

                if let progress =
                    viewModel
                        .progressText(
                            for: session
                        )
                {
                    Text(progress)
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                }
            }

            Spacer(
                minLength: AppSpacing.sm
            )
        }
        .padding(
            .vertical,
            AppSpacing.sm
        )
    }

    // MARK: - Empty

    private var emptyState:
        some View
    {
        ContentUnavailableView(
            "No Reading History",
            systemImage:
                "clock.arrow.circlepath",
            description:
                Text(
                    "Finished reading sessions will appear here."
                )
        )
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .top,
            AppSpacing.xxl
        )
        .padding(
            .horizontal,
            AppSpacing.md
        )
    }

    // MARK: - Date

    private func sectionDate(
        _ date: Date
    ) -> String {

        let calendar =
            Calendar.current

        if calendar
            .isDateInToday(
                date
            )
        {
            return "Today"
        }

        if calendar
            .isDateInYesterday(
                date
            )
        {
            return "Yesterday"
        }

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "EEEE, d MMMM"

        return formatter
            .string(
                from: date
            )
    }
}
