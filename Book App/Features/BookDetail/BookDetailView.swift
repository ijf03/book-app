//
//  BookDetailView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailView: View {
    @Environment(\.bookCatalogue) private var repository
    @State private var metadataModel: BookMetadataViewModel
    @State private var metadataRequest = 0
    @State private var showingEditions = false


    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(LibraryStore.self) private var libraryStore: LibraryStore?

    @Environment(BookContentStore.self)
    private var contentStore

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
    
    @State
    private var isShowingCompletionPrompt =
        false

    @State
    private var isShowingCompletionReview =
        false

    @State
    private var isShowingCompletionNote =
        false
    
    let onBookUpdated:
        (Book) -> Void

    let onBookRemoved:
        (String) -> Void
    
    let onGoHome:
        () -> Void
    
    init(
        book: Book,
        onBookUpdated:
            @escaping (Book) -> Void =
                { _ in },
        onBookRemoved:
            @escaping (String) -> Void =
                { _ in },
        onGoHome:
            @escaping () -> Void =
                {}
    ) {
        _metadataModel = State(initialValue: BookMetadataViewModel(book: BookSearchResult(book: book)))
        _viewModel =
            State(
                initialValue:
                    BookDetailViewModel(
                        book: book
                    )
            )

        self.onBookUpdated =
            onBookUpdated

        self.onBookRemoved =
            onBookRemoved

        self.onGoHome =
            onGoHome
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

                bookActionsSection

                if let error = libraryStore?.persistenceError {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityLabel("Could not save book. \(error)")
                }

                manageSection

                BookMetadataSection(book: BookSearchResult(book: viewModel.book),
                                    isLoading: metadataModel.isLoading, error: metadataModel.error,
                                    retry: { metadataRequest += 1 }, chooseEdition: { showingEditions = true })
            }
            .padding(
                AppSpacing.md
            )
        }
        .background(
            Color.surfaceSecondary
        )
        .onChange(of: libraryStore?.accountScope?.cloudRevision) { _, _ in
            guard let libraryStore else { return }
            if let updated = libraryStore.books.first(where: { $0.id == viewModel.book.id }) {
                viewModel.updateBook(updated)
            } else {
                dismiss()
            }
        }
        .navigationTitle(
            "Book Details"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )

        .task(id: metadataRequest) {
            guard let repository, let libraryStore else { return }
            await metadataModel.load(using: repository, scope: libraryStore.accountScope)
            guard !Task.isCancelled, libraryStore.accountScope?.isActive != false,
                  metadataModel.error == nil, metadataModel.result.metadata != nil else { return }
            libraryStore.applyMetadata(metadataModel.result, bookID: viewModel.book.id)
            if let updated = libraryStore.book(id: viewModel.book.id) { viewModel.updateBook(updated) }
        }
        .sheet(isPresented: $showingEditions) {
            BookEditionPicker(model: metadataModel, scope: libraryStore?.accountScope) { _ in
                guard let libraryStore else { return }
                libraryStore.applyMetadata(metadataModel.result, bookID: viewModel.book.id, selectingEdition: true)
                if let updated = libraryStore.book(id: viewModel.book.id) { viewModel.updateBook(updated) }
            }
        }

        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Book actions", systemImage: "ellipsis.circle") {
                    Button(viewModel.primaryActionTitle, systemImage: "book") { primaryActionTapped() }
                    if viewModel.shouldShowReadingProgress {
                        Button("Update progress", systemImage: "pencil") { isShowingUpdateProgress = true }
                    }
                    Button("Write or edit review", systemImage: "star") { isShowingCompletionReview = true }
                    Button("Add a note", systemImage: "note.text") { isShowingCompletionNote = true }
                    Button("Change reading status", systemImage: "arrow.triangle.2.circlepath") { isShowingStatusSheet = true }
                }
                .accessibilityLabel("Book actions")
            }
        }

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
                },
                onCompleted: {
                    _ in

                    isShowingCompletionPrompt =
                        true
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
        
        // MARK: Completion Review

        .sheet(
            isPresented:
                $isShowingCompletionReview
        ) {

            NavigationStack {

                BookReviewView(
                    book:
                        viewModel.book,
                    existingReview:
                        contentStore.review(
                            for:
                                viewModel.book.id
                        )
                )
            }
        }

        // MARK: Completion Note

        .sheet(
            isPresented:
                $isShowingCompletionNote
        ) {

            NavigationStack {

                NoteEditorView(
                    bookID:
                        viewModel.book.id,
                    onSave: {
                        note in

                        contentStore
                            .addNote(
                                note
                            )
                    }
                )
            }
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
        
        .confirmationDialog(
            "You finished \(viewModel.book.title)!",
            isPresented:
                $isShowingCompletionPrompt,
            titleVisibility:
                .visible
        ) {

            Button(
                "Write a Review"
            ) {
                isShowingCompletionReview =
                    true
            }

            Button(
                "Add a Note"
            ) {
                isShowingCompletionNote =
                    true
            }

            Button(
                "Back to Home"
            ) {
                dismiss()
                onGoHome()
            }

            Button(
                "Stay on Book Details",
                role: .cancel
            ) {}

        } message: {

            Text(
                "Would you like to save some thoughts before you move on?"
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

                VStack(
                    spacing: 0
                ) {

                    NavigationLink {
                        PastReadsView(bookID: viewModel.book.id)
                    } label: {
                        BookDetailNavigationRow(title: "Past reads", systemImage: "clock.arrow.circlepath",
                                                subtitle: "Your completed reading dates")
                    }
                    .buttonStyle(.plain)

                    Divider()

                    NavigationLink {

                        BookNotesView(
                            book:
                                viewModel.book
                        )

                    } label: {

                        BookDetailNavigationRow(
                            title: "Notes",
                            systemImage:
                                "note.text",
                            subtitle:
                                notesSubtitle
                        )
                    }
                    .buttonStyle(
                        .plain
                    )

                    Divider()
                        .padding(
                            .leading,
                            38 +
                            AppSpacing.md
                        )

                    NavigationLink {

                        BookReviewView(
                            book:
                                viewModel.book,
                            existingReview:
                                contentStore
                                    .review(
                                        for:
                                            viewModel
                                                .book.id
                                    )
                        )

                    } label: {

                        BookDetailNavigationRow(
                            title:
                                reviewTitle,
                            systemImage:
                                "star",
                            subtitle:
                                reviewSubtitle
                        )
                    }
                    .buttonStyle(
                        .plain
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
                        .padding(
                            .leading,
                            38 + AppSpacing.md
                        )

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

    private var reviewTitle:
        String
    {
        if contentStore.review(
            for:
                viewModel.book.id
        ) != nil
        {
            return "Edit Review"
        }

        return viewModel.book.status ==
            .completed
            ? "Write a Review"
            : "Review"
    }
    
    private var notesSubtitle:
        String
    {
        let count =
            contentStore
                .notes(
                    for:
                        viewModel
                            .book.id
                )
                .count

        switch count {

        case 0:
            return
                "View or add reading notes"

        case 1:
            return
                "1 saved note"

        default:
            return
                "\(count) saved notes"
        }
    }

    private var reviewSubtitle:
        String
    {
        guard let review =
            contentStore.review(
                for:
                    viewModel
                        .book.id
            )
        else {
            return
                "Record your thoughts"
        }

        return
            "\(review.rating) out of 5 stars"
    }

    // MARK: - Progress

    private func saveUpdatedBook(
        _ updatedBook: Book
    ) {

        onBookUpdated(updatedBook)
        viewModel.updateBook(libraryStore?.book(id: updatedBook.id) ?? updatedBook)
    }

    // MARK: - Primary Action

    private func primaryActionTapped() {

        switch viewModel.book.status {

        case .reading:

            isShowingReadingSession =
                true

        case .toRead, .abandoned:

            changeStatus(
                to: .reading
            )

            isShowingReadingSession =
                true

        case .completed:
            changeStatus(to: .reading)
            // A failed local save must leave the completed read intact.
            isShowingReadingSession = viewModel.book.status == .reading
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

        saveUpdatedBook(updatedBook)
    }

    // MARK: - Removal

    private func removeBookTapped() {

        isShowingRemoveAlert =
            true
    }

    private func confirmRemoveBook() {

        let bookID =
            viewModel.book.id

        contentStore
            .deleteAllContent(
                for: bookID
            )

        onBookRemoved(
            bookID
        )

        dismiss()
    }
}

#Preview {

    let sessionStore =
        ReadingSessionStore(
            sessions: [],
            localDataSource:
                LocalReadingSessionDataSource()
        )

    let contentStore =
        BookContentStore(
            notes: [],
            reviews: [],
            localDataSource:
                LocalBookContentDataSource()
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
    .environment(
        contentStore
    )
}
