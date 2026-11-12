//
//  NoteEditorView.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct NoteEditorView: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    @Environment(\.dismiss)
    private var dismiss

    let bookID: String

    let existingNote:
        ReadingNote?

    let onSave:
        (ReadingNote) -> Void

    @State
    private var text: String

    @State
    private var pageText: String

    @State
    private var containsSpoilers:
        Bool

    init(
        bookID: String,
        note: ReadingNote? = nil,
        onSave:
            @escaping (ReadingNote) -> Void
    ) {
        self.bookID = bookID
        self.existingNote = note
        self.onSave = onSave

        _text = State(
            initialValue:
                note?.text ?? ""
        )

        _pageText = State(
            initialValue:
                note?.page
                    .map(String.init) ??
                ""
        )

        _containsSpoilers =
            State(
                initialValue:
                    note?
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

                noteSection

                detailsSection
            }
            .padding(
                AppSpacing.md
            )
        }
        .background(
            Color.surfaceSecondary
        )
        .navigationTitle(
            existingNote == nil
            ? "New Note"
            : "Edit Note"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .safeAreaInset(
            edge: .bottom
        ) {

            Button(
                existingNote == nil
                ? "Save Note"
                : "Save Changes"
            ) {
                save()
            }
            .buttonStyle(
                AppButtonStyle(
                    kind: .primary
                )
            )
            .disabled(
                trimmedText.isEmpty
            )
            .padding(
                AppSpacing.md
            )
            .background(
                Color.surface
            )
        }
    }

    private var noteSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Note"
            )

            AppCard {

                TextEditor(
                    text: $text
                )
                .accessibilityLabel("Reading note")
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

    private var detailsSection:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: AppSpacing.sm
        ) {

            SectionHeader(
                title: "Details"
            )

            AppCard {

                VStack(
                    spacing: AppSpacing.md
                ) {

                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
                        : AnyLayout(HStackLayout())
                    layout {

                        VStack(
                            alignment: .leading,
                            spacing:
                                AppSpacing.xs
                        ) {

                            Text(
                                "Page"
                            )
                            .font(
                                AppTypography.headline
                            )

                            Text(
                                "Optional"
                            )
                            .font(
                                AppTypography.caption
                            )
                            .foregroundStyle(
                                Color.textSecondary
                            )
                        }

                        Spacer()

                        TextField(
                            "Page",
                            text:
                                $pageText
                        )
                        .keyboardType(
                            .numberPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(
                            width: typeSize.isAccessibilitySize ? nil : 90
                        )
                        .textFieldStyle(
                            .roundedBorder
                        )
                    }

                    Divider()

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
                                "Hide this note until it is revealed."
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
        }
    }

    private var trimmedText:
        String
    {
        text.trimmingCharacters(
            in:
                .whitespacesAndNewlines
        )
    }

    private func save() {

        guard !trimmedText.isEmpty
        else {
            return
        }

        let page =
            Int(pageText)

        let note =
            ReadingNote(
                id:
                    existingNote?.id ??
                    UUID(),
                bookID:
                    bookID,
                text:
                    trimmedText,
                page:
                    page,
                containsSpoilers:
                    containsSpoilers,
                createdAt:
                    existingNote?
                        .createdAt ??
                    Date(),
                updatedAt:
                    Date()
            )

        onSave(note)

        dismiss()
    }
}
