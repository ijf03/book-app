//
//  BookDetailView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var viewModel:
        BookDetailViewModel

    @State
    private var isShowingUpdateProgress =
        false

    @State
    private var isShowingStatusSheet =
        false

    @State
    private var isShowingRemoveAlert =
        false
    
    @State
    private var isShowingReadingSession =
        false
    
    let onBookUpdated:
        (Book) -> Void

    let onBookRemoved:
        (String) -> Void

    init(
        book: Book,
        onBookUpdated:
            @escaping (Book) -> Void =
                { _ in },
        onBookRemoved:
            @escaping (String) -> Void =
                { _ in }
    ) {
        _viewModel = State(
            initialValue:
                BookDetailViewModel(
                    book: book
                )
        )

        self.onBookUpdated =
            onBookUpdated

        self.onBookRemoved =
            onBookRemoved
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
                    book:
                        viewModel.book,
                    primaryActionTitle:
                        viewModel
                            .primaryActionTitle,
                    primaryAction: {
                        primaryActionTapped()
                    },
                    secondaryAction:
                        viewModel
                            .shouldShowReadingProgress
                        ? {
                            isShowingUpdateProgress =
                                true
                        }
                        : nil
                )

                aboutSection

                bookActionsSection

                manageSection
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

        // MARK: Update Progress

        .navigationDestination(
            isPresented:
                $isShowingUpdateProgress
        ) {
            UpdateProgressView(
                book:
                    viewModel.book,
                onSave: {
                    updatedBook in

                    saveUpdatedBook(
                        updatedBook
                    )
                }
            )
        }
        
        .navigationDestination(
            isPresented:
                $isShowingReadingSession
        ) {
            ReadingSessionView(
                book:
                    viewModel.book,
                onBookUpdated: {
                    updatedBook in

                    saveUpdatedBook(
                        updatedBook
                    )
                }
            )
        }

        // MARK: Change Status

        .sheet(
            isPresented:
                $isShowingStatusSheet
        ) {
            ChangeReadingStatusSheet(
                currentStatus:
                    viewModel.book.status,
                onSave: {
                    newStatus in

                    changeStatus(
                        to: newStatus
                    )
                }
            )
            .presentationDetents(
                [
                    .medium,
                    .large
                ]
            )
        }

        // MARK: Remove

        .alert(
            "Remove From Library?",
            isPresented:
                $isShowingRemoveAlert
        ) {
            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button(
                "Remove",
                role: .destructive
            ) {
                confirmRemoveBook()
            }

        } message: {

            Text(
                """
                "\(viewModel.book.title)" will be removed from your library.
                """
            )
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection:
        some View
    {
        if let description =
            viewModel.book.description
        {
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
    }

    // MARK: - Book Actions

    private var bookActionsSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Your Book"
            )

            AppCard {
                VStack(spacing: 0) {

                    BookDetailActionRow(
                        title: "Notes",
                        systemImage:
                            "note.text",
                        subtitle:
                            "View or add reading notes",
                        action: {
                            notesTapped()
                        }
                    )

                    Divider()

                    BookDetailActionRow(
                        title:
                            reviewTitle,
                        systemImage:
                            "star",
                        subtitle:
                            "Record your thoughts",
                        action: {
                            reviewTapped()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Manage

    private var manageSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Manage"
            )

            AppCard {
                VStack(spacing: 0) {

                    BookDetailActionRow(
                        title:
                            "Change Reading Status",
                        systemImage:
                            "arrow.triangle.2.circlepath",
                        subtitle:
                            viewModel
                                .book
                                .status
                                .displayName,
                        action: {
                            changeStatusTapped()
                        }
                    )

                    Divider()

                    BookDetailActionRow(
                        title:
                            "Remove From Library",
                        systemImage:
                            "trash",
                        subtitle:
                            "Delete this book from your library",
                        action: {
                            removeBookTapped()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Review

    private var reviewTitle: String {

        viewModel.book.status ==
            .completed
        ? "Write a Review"
        : "Review"
    }

    // MARK: - Progress

    private func saveUpdatedBook(
        _ updatedBook: Book
    ) {

        viewModel.updateBook(
            updatedBook
        )

        onBookUpdated(
            updatedBook
        )
    }

    // MARK: - Primary Action

    private func primaryActionTapped() {

        switch viewModel.book.status {

        case .reading:

            isShowingReadingSession =
                true

        case .toRead:

            changeStatus(
                to: .reading
            )

            isShowingReadingSession =
                true

        case .completed:

            changeStatus(
                to: .reading
            )

            isShowingReadingSession =
                true
        }
    }

    // MARK: - Status

    private func changeStatusTapped() {

        isShowingStatusSheet =
            true
    }

    private func changeStatus(
        to status: ReadingStatus
    ) {

        guard status !=
                viewModel.book.status
        else {
            return
        }

        let updatedBook =
            viewModel.updateStatus(
                status
            )

        onBookUpdated(
            updatedBook
        )
    }

    // MARK: - Removal

    private func removeBookTapped() {

        isShowingRemoveAlert =
            true
    }

    private func confirmRemoveBook() {

        let bookID =
            viewModel.book.id

        onBookRemoved(
            bookID
        )

        dismiss()
    }

    // MARK: - Future Features

    private func notesTapped() {
        print(
            "Notes tapped"
        )
    }

    private func reviewTapped() {
        print(
            "Review tapped"
        )
    }
}

#Preview {

    let dataSource =
        LocalReadingSessionDataSource()

    let sessionStore =
        ReadingSessionStore(
            sessions: [],
            localDataSource:
                dataSource
        )

    NavigationStack {
        BookDetailView(
            book:
                .mockFourthWing
        )
    }
    .environment(
        sessionStore
    )
}
