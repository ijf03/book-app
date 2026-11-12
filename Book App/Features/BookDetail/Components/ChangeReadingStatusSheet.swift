//
//  ChangeReadingStatusSheet.swift
//  Book App
//
//  Created by Sabi on 11/10/2026.
//

import SwiftUI

struct ChangeReadingStatusSheet: View {

    @Environment(\.dismiss)
    private var dismiss

    let currentStatus: ReadingStatus
    let onSave: (ReadingStatus) -> Void

    @State
    private var selectedStatus: ReadingStatus

    init(
        currentStatus: ReadingStatus,
        onSave: @escaping (ReadingStatus) -> Void
    ) {
        self.currentStatus = currentStatus
        self.onSave = onSave

        _selectedStatus = State(
            initialValue: currentStatus
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.lg
                ) {

                    Text(
                        "Choose where this book belongs in your library."
                    )
                    .font(AppTypography.body)
                    .foregroundStyle(
                        Color.textSecondary
                    )

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(
                            ReadingStatus.allCases
                        ) { status in

                            statusButton(
                                status
                            )
                        }
                    }

                    Spacer()
                }
                .padding(
                    AppSpacing.md
                )
            }
            .background(
                Color.surfaceSecondary
            )
            .navigationTitle(
                "Reading Status"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(
                edge: .bottom
            ) {
                Button(
                    "Save Status"
                ) {
                    onSave(
                        selectedStatus
                    )

                    dismiss()
                }
                .buttonStyle(
                    AppButtonStyle(
                        kind: .primary
                    )
                )
                .disabled(
                    selectedStatus ==
                        currentStatus
                )
                .padding(
                    AppSpacing.md
                )
                .background(
                    Color.surface
                )
            }
        }
    }

    // MARK: - Status Option

    private func statusButton(
        _ status: ReadingStatus
    ) -> some View {

        Button {
            selectedStatus =
                status
        } label: {

            AppCard {
                HStack(
                    spacing: AppSpacing.md
                ) {

                    Image(
                        systemName:
                            icon(
                                for: status
                            )
                    )
                    .frame(width: 24)
                    .foregroundStyle(
                        Color.appAccent
                    )

                    VStack(
                        alignment: .leading,
                        spacing: AppSpacing.xs
                    ) {

                        Text(
                            status.displayName
                        )
                        .font(
                            AppTypography.headline
                        )
                        .foregroundStyle(
                            Color.textPrimary
                        )

                        Text(
                            description(
                                for: status
                            )
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                    }

                    Spacer()

                    Image(
                        systemName:
                            selectedStatus ==
                                status
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        selectedStatus ==
                            status
                        ? Color.appAccent
                        : Color.textSecondary
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedStatus == status ? .isSelected : [])
    }

    // MARK: - Helpers

    private func icon(
        for status: ReadingStatus
    ) -> String {

        switch status {
        case .reading:
            return "book"

        case .toRead:
            return "bookmark"

        case .completed:
            return "checkmark.circle"
        case .abandoned:
            return "book.closed"
        }
    }

    private func description(
        for status: ReadingStatus
    ) -> String {

        switch status {
        case .reading:
            return "You're currently reading this book."

        case .toRead:
            return "Keep this book for later."

        case .completed:
            return "You've finished reading this book."
        case .abandoned:
            return "Keep your progress and record that you stopped reading this book."
        }
    }
}
