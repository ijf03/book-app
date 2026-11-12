//
//  UpdateProgressView.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import SwiftUI

struct UpdateProgressView: View {

    @Environment(BookContentStore.self) private var contentStore: BookContentStore?
    @State private var noteDraft = ProgressNoteDraft()

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var viewModel: UpdateProgressViewModel

    let book: Book
    let onSave: (Book) -> Void
    let onCompleted: ((Book) -> Void)?
    let onSaveAndEndSession: ((Book) -> Void)?

    @State
    private var completedBookToReport:
        Book?

    init(
        book: Book,
        onSave:
            @escaping (Book) -> Void,
        onCompleted:
            ((Book) -> Void)? = nil,
        onSaveAndEndSession:
            ((Book) -> Void)? = nil
    ) {
        self.book =
            book

        self.onSave =
            onSave

        self.onCompleted =
            onCompleted

        self.onSaveAndEndSession =
            onSaveAndEndSession

        _viewModel =
            State(
                initialValue:
                    UpdateProgressViewModel(
                        book: book
                    )
            )
    }
    
    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.lg
            ) {
                currentProgressSection

                instructionSection

                progressFields

                if let validationMessage =
                    viewModel.validationMessage
                {
                    validationError(
                        validationMessage
                    )
                }

                summarySection

                ProgressNoteSection(draft: noteDraft)
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Update Progress")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(
                spacing: AppSpacing.sm
            ) {

                Button("Save Progress") {
                    saveProgress()
                }
                .buttonStyle(
                    AppButtonStyle(
                        kind: .primary
                    )
                )
                .disabled(
                    !viewModel.canSave || !noteDraft.canSave
                )

                if let onSaveAndEndSession {

                    Button(
                        "Save & End Session"
                    ) {
                        guard let updatedBook =
                            viewModel.makeUpdatedBook()
                        else {
                            return
                        }

                        guard noteDraft.save(bookID: book.id, page: updatedBook.progress.page, to: contentStore) else { return }

                        onSaveAndEndSession(
                            updatedBook
                        )
                    }
                    .buttonStyle(
                        AppButtonStyle(
                            kind: .secondary
                        )
                    )
                    .disabled(
                        !viewModel.canSave || !noteDraft.canSave
                    )
                }
            }
            .onDisappear {

                guard let completedBook =
                    completedBookToReport
                else {
                    return
                }

                completedBookToReport =
                    nil

                onCompleted?(
                    completedBook
                )
            }
            .padding(
                AppSpacing.md
            )
            .background(
                Color.surface
            )
        }
    }

    // MARK: - Current Progress

    private var currentProgressSection: some View {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {
            Text(viewModel.originalBook.title)
                .font(AppTypography.headline)
                .foregroundStyle(Color.textPrimary)

            AppCard {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.sm
                ) {
                    Text("Current")
                        .font(AppTypography.caption)
                        .foregroundStyle(
                            Color.textSecondary
                        )

                    ProgressBar(
                        progress:
                            viewModel
                                .currentProgressFraction
                    )

                    Text(
                        viewModel
                            .currentProgressDescription
                    )
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    // MARK: - Instructions

    private var instructionSection: some View {
        Text(
            "Choose a format and enter your position. Your shared percentage follows you when you switch formats."
        )
        .font(AppTypography.body)
        .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Fields

    private var progressFields: some View {
        ProgressEntryFields(model: viewModel)
    }

    // MARK: - Validation

    private func validationError(
        _ message: String
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: AppSpacing.sm
        ) {
            Image(
                systemName:
                    "exclamationmark.circle"
            )

            Text(message)
                .font(AppTypography.caption)
        }
        .foregroundStyle(Color.danger)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - Summary

    private var summarySection: some View {
        AppCard {
            VStack(
                alignment: .leading,
                spacing: AppSpacing.xs
            ) {
                Text("This update will save")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(viewModel.saveSummary)
                    .font(AppTypography.body)
                    .foregroundStyle(
                        Color.textSecondary
                    )
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        VStack {
            Button("Save Progress") {
                saveProgress()
            }
            .buttonStyle(
                AppButtonStyle(kind: .primary)
            )
            .disabled(!viewModel.canSave)
        }
        .padding(AppSpacing.md)
        .background(Color.surface)
    }

    private func saveProgress() {

        guard let updatedBook =
            viewModel
                .makeUpdatedBook()
        else {
            return
        }

        guard noteDraft.save(bookID: book.id, page: updatedBook.progress.page, to: contentStore) else { return }

        let justCompleted =
            updatedBook.status ==
                .completed &&
            book.status !=
                .completed

        onSave(
            updatedBook
        )

        if justCompleted {
            completedBookToReport =
                updatedBook
        }

        dismiss()
    }
    
}

#Preview {
    NavigationStack {
        UpdateProgressView(
            book: .mockFourthWing,
            onSave: { _ in }
        )
    }
}
