//
//  UpdateProgressView.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import SwiftUI

struct UpdateProgressView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var viewModel: UpdateProgressViewModel

    let onSave: (Book) -> Void

    init(
        book: Book,
        onSave: @escaping (Book) -> Void
    ) {
        _viewModel = State(
            initialValue: UpdateProgressViewModel(
                book: book
            )
        )

        self.onSave = onSave
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
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Update Progress")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            saveButton
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
            "Use any one field, or combine page, percentage and timestamp."
        )
        .font(AppTypography.body)
        .foregroundStyle(Color.textSecondary)
    }

    // MARK: - Fields

    private var progressFields: some View {
        VStack(spacing: AppSpacing.md) {

            FieldToggleRow(
                title: "Page",
                helperText: "Physical or ebook",
                placeholder: "0",
                keyboardType: .numberPad,
                isEnabled: pageEnabledBinding,
                text: pageBinding
            )

            FieldToggleRow(
                title: "Percentage",
                helperText: "Works with any format",
                placeholder: "0",
                keyboardType: .decimalPad,
                isEnabled:
                    percentageEnabledBinding,
                text: percentageBinding
            )

            FieldToggleRow(
                title: "Timestamp",
                helperText: "HH:MM:SS for audio",
                placeholder: "00:00:00",
                keyboardType:
                    .numbersAndPunctuation,
                isEnabled:
                    timestampEnabledBinding,
                text: timestampBinding
            )
        }
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
        guard
            let updatedBook =
                viewModel.makeUpdatedBook()
        else {
            return
        }

        onSave(updatedBook)
        dismiss()
    }

    // MARK: - Bindings

    private var pageEnabledBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                viewModel.isPageEnabled
            },
            set: {
                viewModel.isPageEnabled = $0
            }
        )
    }

    private var percentageEnabledBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                viewModel.isPercentageEnabled
            },
            set: {
                viewModel
                    .isPercentageEnabled = $0
            }
        )
    }

    private var timestampEnabledBinding:
        Binding<Bool>
    {
        Binding(
            get: {
                viewModel.isTimestampEnabled
            },
            set: {
                viewModel
                    .isTimestampEnabled = $0
            }
        )
    }

    private var pageBinding: Binding<String> {
        Binding(
            get: {
                viewModel.pageText
            },
            set: {
                viewModel.updatePage($0)
            }
        )
    }

    private var percentageBinding:
        Binding<String>
    {
        Binding(
            get: {
                viewModel.percentageText
            },
            set: {
                viewModel.updatePercentage($0)
            }
        )
    }

    private var timestampBinding:
        Binding<String>
    {
        Binding(
            get: {
                viewModel.timestampText
            },
            set: {
                viewModel.updateTimestamp($0)
            }
        )
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
