//
//  BookReviewView.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct BookReviewView: View {

    @Environment(BookContentStore.self)
    private var contentStore

    @Environment(\.dismiss)
    private var dismiss

    let book: Book
    @State private var mood: String

    @State
    private var rating: Int

    @State
    private var reviewText:
        String

    @State
    private var containsSpoilers:
        Bool

    @State
    private var isShowingDeleteAlert =
        false

    private let originalReview:
        BookReview?

    init(
        book: Book,
        existingReview:
            BookReview?
    ) {
        self.book = book
        _mood = State(initialValue: existingReview?.mood ?? "")
        self.originalReview =
            existingReview

        _rating = State(
            initialValue:
                existingReview?
                    .rating ??
                0
        )

        _reviewText = State(
            initialValue:
                existingReview?
                    .text ??
                ""
        )

        _containsSpoilers =
            State(
                initialValue:
                    existingReview?
                        .containsSpoilers ??
                    false
            )
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: AppSpacing.xl
            ) {

                ratingSection

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("How did this book leave you feeling?").font(AppTypography.headline)
                        TextField("Mood, for example Hopeful or Reflective", text: $mood)
                            .textInputAutocapitalization(.words)
                        Text("Optional. Record your feeling after finishing the book; this appears in your mood statistics.")
                            .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                    }
                }
                reviewSection

                spoilerSection

                if originalReview != nil {

                    deleteSection
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
            originalReview == nil
            ? "Write a Review"
            : "Edit Review"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .safeAreaInset(
            edge: .bottom
        ) {

            Button(
                originalReview == nil
                ? "Save Review"
                : "Save Changes"
            ) {
                saveReview()
            }
            .buttonStyle(
                AppButtonStyle(
                    kind: .primary
                )
            )
            .disabled(
                rating == 0 || mood.count > 100
            )
            .padding(
                AppSpacing.md
            )
            .background(
                Color.surface
            )
        }
        .alert(
            "Delete Review?",
            isPresented:
                $isShowingDeleteAlert
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {}

            Button(
                "Delete",
                role: .destructive
            ) {
                contentStore
                    .deleteReview(
                        for:
                            book.id
                    )

                dismiss()
            }

        } message: {

            Text(
                "Your rating and review text will be permanently deleted."
            )
        }
    }

    // MARK: - Rating

    private var ratingSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Your Rating"
            )

            AppCard {

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.sm
                ) {

                    RatingStars(
                        rating:
                            $rating
                    )

                    Text(
                        rating == 0
                        ? "Tap a star to rate this book."
                        : "\(rating) out of 5 stars"
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }
            }
        }
    }

    // MARK: - Review

    private var reviewSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Review"
            )

            AppCard {

                TextEditor(
                    text:
                        $reviewText
                )
                .font(
                    AppTypography.body
                )
                .foregroundStyle(
                    Color.textPrimary
                )
                .frame(
                    minHeight: 180
                )
                .scrollContentBackground(
                    .hidden
                )
            }
        }
    }

    // MARK: - Spoiler

    private var spoilerSection:
        some View
    {
        AppCard {

            Toggle(
                isOn:
                    $containsSpoilers
            ) {

                VStack(
                    alignment: .leading,
                    spacing:
                        AppSpacing.xs
                ) {

                    Text(
                        "Contains Spoilers"
                    )
                    .font(
                        AppTypography.headline
                    )

                    Text(
                        "Your review will be marked as containing spoilers."
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                }
            }
            .tint(
                Color.appAccent
            )
        }
    }

    // MARK: - Delete

    private var deleteSection:
        some View
    {
        Button(
            "Delete Review",
            role: .destructive
        ) {
            isShowingDeleteAlert =
                true
        }
        .font(
            AppTypography.headline
        )
        .foregroundStyle(
            Color.danger
        )
        .frame(
            maxWidth: .infinity
        )
        .frame(
            minHeight: 48
        )
        .background {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .fill(
                Color.surface
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius:
                    AppRadius.md,
                style:
                    .continuous
            )
            .stroke(
                Color.danger,
                lineWidth: 1
            )
        }
    }

    // MARK: - Save

    private func saveReview() {

        guard rating > 0
        else {
            return
        }

        let review =
            BookReview(
                id:
                    originalReview?
                        .id ??
                    UUID(),
                bookID:
                    book.id,
                rating:
                    rating,
                text:
                    reviewText
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                containsSpoilers:
                    containsSpoilers,
                createdAt:
                    originalReview?
                        .createdAt ??
                    Date(),
                updatedAt:
                    Date(),
                mood: mood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : mood.trimmingCharacters(in: .whitespacesAndNewlines)
            )

        contentStore
            .saveReview(
                review
            )

        dismiss()
    }
}
