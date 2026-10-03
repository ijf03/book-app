//
//  BookDetailView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailView: View {
    @State private var viewModel: BookDetailViewModel

    init(book: Book) {
        _viewModel = State(
            initialValue: BookDetailViewModel(book: book)
        )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.xl
            ) {
                BookDetailHeader(
                    book: viewModel.book
                )

                BookStatusCard(
                    book: viewModel.book,
                    primaryActionTitle: viewModel.primaryActionTitle,
                    primaryAction: {
                        primaryActionTapped()
                    },
                    secondaryAction:
                        viewModel.shouldShowReadingProgress
                        ? {
                            updateProgressTapped()
                        }
                        : nil
                )

                aboutSection

                bookActionsSection

                manageSection
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        if let description = viewModel.book.description {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.sm
            ) {
                SectionHeader(title: "About")

                Text(description)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textPrimary)
            }
        }
    }

    // MARK: - Book Actions

    private var bookActionsSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            SectionHeader(title: "Your Book")

            AppCard {
                VStack(spacing: 0) {
                    BookDetailActionRow(
                        title: "Notes",
                        systemImage: "note.text",
                        subtitle: "View or add reading notes",
                        action: {
                            notesTapped()
                        }
                    )

                    Rectangle()
                        .fill(Color.divider)
                        .frame(height: 1)

                    BookDetailActionRow(
                        title: reviewTitle,
                        systemImage: "star",
                        subtitle: "Record your thoughts",
                        action: {
                            reviewTapped()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Manage

    private var manageSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            SectionHeader(title: "Manage")

            AppCard {
                VStack(spacing: 0) {
                    BookDetailActionRow(
                        title: "Change Reading Status",
                        systemImage: "arrow.triangle.2.circlepath",
                        action: {
                            changeStatusTapped()
                        }
                    )

                    Rectangle()
                        .fill(Color.divider)
                        .frame(height: 1)

                    BookDetailActionRow(
                        title: "Remove From Library",
                        systemImage: "trash",
                        action: {
                            removeBookTapped()
                        }
                    )
                }
            }
        }
    }

    private var reviewTitle: String {
        viewModel.book.status == .completed
            ? "Write a Review"
            : "Review"
    }

    // MARK: - Actions

    private func primaryActionTapped() {
        print("Primary action tapped")
    }

    private func updateProgressTapped() {
        print("Update progress tapped")
    }

    private func notesTapped() {
        print("Notes tapped")
    }

    private func reviewTapped() {
        print("Review tapped")
    }

    private func changeStatusTapped() {
        print("Change status tapped")
    }

    private func removeBookTapped() {
        print("Remove book tapped")
    }
}

#Preview {
    NavigationStack {
        BookDetailView(
            book: .mockFourthWing
        )
    }
}
