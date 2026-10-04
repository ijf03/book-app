//
//  AddBookSheet.swift
//  Book App
//
//  Created by Sabi on 4/10/2026.
//

import SwiftUI

struct AddBookSheet: View {

    @Environment(\.dismiss)
    private var dismiss

    let book: BookSearchResult
    let onAdd: (
        ReadingStatus,
        ReadingFormat
    ) -> Void

    @State
    private var selectedStatus:
        ReadingStatus = .toRead

    @State
    private var selectedFormat:
        ReadingFormat = .physical

    var body: some View {
        NavigationStack {
            Form {

                Section(
                    "Reading Status"
                ) {
                    Picker(
                        "Status",
                        selection:
                            $selectedStatus
                    ) {
                        ForEach(
                            ReadingStatus.allCases
                        ) { status in
                            Text(
                                status.displayName
                            )
                            .tag(status)
                        }
                    }
                }

                Section(
                    "Reading Format"
                ) {
                    Picker(
                        "Format",
                        selection:
                            $selectedFormat
                    ) {
                        ForEach(
                            ReadingFormat.allCases
                        ) { format in
                            Text(
                                format.displayName
                            )
                            .tag(format)
                        }
                    }
                }
            }
            .navigationTitle(
                "Add to Library"
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
                    "Add to Library"
                ) {
                    onAdd(
                        selectedStatus,
                        selectedFormat
                    )

                    dismiss()
                }
                .buttonStyle(
                    AppButtonStyle(
                        kind: .primary
                    )
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
}
