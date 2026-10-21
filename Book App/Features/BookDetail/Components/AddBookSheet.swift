import SwiftUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: BookSearchResult
    let onAdd: (ReadingStatus, ReadingFormat) -> Bool
    @State private var selectedStatus: ReadingStatus = .toRead
    @State private var selectedFormat: ReadingFormat = .physical
    @State private var isShowingSaveError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }
                Section("Reading Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ReadingFormat.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
            }
            .navigationTitle("Add to Library")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn’t Save Book", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your book wasn’t added. Your selections are still here. Please try Add to Library again.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add to Library") {
                    if onAdd(selectedStatus, selectedFormat) {
                        dismiss()
                    } else {
                        isShowingSaveError = true
                    }
                }
                .buttonStyle(AppButtonStyle(kind: .primary))
                .padding(AppSpacing.md)
                .background(Color.surface)
            }
        }
    }
}
