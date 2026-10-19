//
//  BookNotesView.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct BookNotesView: View {

    @Environment(BookContentStore.self)
    private var contentStore

    let book: Book

    @State
    private var isAddingNote =
        false

    @State
    private var noteToEdit:
        ReadingNote?

    @State
    private var noteToDelete:
        ReadingNote?

    @State
    private var revealedSpoilers:
        Set<UUID> = []

    private var notes:
        [ReadingNote]
    {
        contentStore.notes(
            for: book.id
        )
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: AppSpacing.lg
            ) {

                if notes.isEmpty {

                    emptyState

                } else {

                    ForEach(notes) {
                        note in

                        noteCard(note)
                    }
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
            "Notes"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {

            ToolbarItem(
                placement:
                    .topBarTrailing
            ) {

                Button {
                    isAddingNote =
                        true

                } label: {

                    Image(
                        systemName:
                            "plus"
                    )
                }
            }
        }
        .navigationDestination(
            isPresented:
                $isAddingNote
        ) {

            NoteEditorView(
                bookID:
                    book.id,
                onSave: {
                    note in

                    contentStore
                        .addNote(
                            note
                        )
                }
            )
        }
        .navigationDestination(
            item:
                $noteToEdit
        ) { note in

            NoteEditorView(
                bookID:
                    book.id,
                note: note,
                onSave: {
                    updatedNote in

                    contentStore
                        .updateNote(
                            updatedNote
                        )
                }
            )
        }
        .alert(
            "Delete Note?",
            isPresented:
                Binding(
                    get: {
                        noteToDelete !=
                            nil
                    },
                    set: {
                        newValue in

                        if !newValue {
                            noteToDelete =
                                nil
                        }
                    }
                )
        ) {

            Button(
                "Cancel",
                role: .cancel
            ) {
                noteToDelete =
                    nil
            }

            Button(
                "Delete",
                role: .destructive
            ) {

                if let note =
                    noteToDelete
                {
                    contentStore
                        .deleteNote(
                            id:
                                note.id
                        )
                }

                noteToDelete =
                    nil
            }

        } message: {

            Text(
                "This note will be permanently deleted."
            )
        }
    }

    // MARK: - Empty

    private var emptyState:
        some View
    {
        ContentUnavailableView(
            "No Notes Yet",
            systemImage:
                "note.text",
            description:
                Text(
                    "Save thoughts, quotes, or moments you want to remember."
                )
        )
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .top,
            AppSpacing.xxl
        )
    }

    // MARK: - Card

    private func noteCard(
        _ note: ReadingNote
    ) -> some View {

        AppCard {

            VStack(
                alignment: .leading,
                spacing: AppSpacing.md
            ) {

                HStack {

                    if let page =
                        note.page
                    {
                        Text(
                            "Page \(page)"
                        )
                        .font(
                            AppTypography.caption
                        )
                        .foregroundStyle(
                            Color.appAccent
                        )
                    }

                    Spacer()

                    Text(
                        formattedDate(
                            note.updatedAt
                        )
                    )
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )

                    Menu {

                        Button {
                            noteToEdit =
                                note
                        } label: {

                            Label(
                                "Edit",
                                systemImage:
                                    "pencil"
                            )
                        }

                        Button(
                            role:
                                .destructive
                        ) {
                            noteToDelete =
                                note

                        } label: {

                            Label(
                                "Delete",
                                systemImage:
                                    "trash"
                            )
                        }

                    } label: {

                        Image(
                            systemName:
                                "ellipsis"
                        )
                        .foregroundStyle(
                            Color.textSecondary
                        )
                        .frame(
                            width: 32,
                            height: 32
                        )
                    }
                }

                if note.containsSpoilers &&
                    !revealedSpoilers
                        .contains(
                            note.id
                        )
                {
                    spoilerButton(
                        note
                    )

                } else {

                    Text(note.text)
                        .font(
                            AppTypography.body
                        )
                        .foregroundStyle(
                            Color.textPrimary
                        )
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )

                    if note.containsSpoilers {

                        Label(
                            "Spoiler",
                            systemImage:
                                "eye.slash"
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
    }

    private func spoilerButton(
        _ note: ReadingNote
    ) -> some View {

        Button {

            revealedSpoilers
                .insert(
                    note.id
                )

        } label: {

            HStack(
                spacing: AppSpacing.sm
            ) {

                Image(
                    systemName:
                        "eye.slash"
                )

                VStack(
                    alignment: .leading,
                    spacing:
                        AppSpacing.xs
                ) {

                    Text(
                        "Spoiler hidden"
                    )
                    .font(
                        AppTypography.headline
                    )

                    Text(
                        "Tap to reveal this note."
                    )
                    .font(
                        AppTypography.caption
                    )
                }

                Spacer()
            }
            .foregroundStyle(
                Color.textPrimary
            )
            .padding(
                AppSpacing.md
            )
            .background {
                RoundedRectangle(
                    cornerRadius:
                        AppRadius.md,
                    style:
                        .continuous
                )
                .fill(
                    Color.accentTint
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.dateStyle =
            .medium

        return formatter
            .string(
                from: date
            )
    }
}
