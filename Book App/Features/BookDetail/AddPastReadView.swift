import SwiftUI

struct AddPastReadView: View {
    let bookID: String
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var model = AddPastReadViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Start date") {
                    Toggle("Unknown start date", isOn: $model.startUnknown)
                    if !model.startUnknown {
                        DatePicker("Started", selection: $model.startDate, in: ...Date(), displayedComponents: .date)
                    }
                }
                Section("Finish date") {
                    Toggle("Unknown finish date", isOn: $model.endUnknown)
                    if !model.endUnknown {
                        DatePicker("Finished", selection: $model.endDate, in: ...Date(), displayedComponents: .date)
                    }
                }
                Section {
                    Text("This adds a separate completed read. Your current progress stays unchanged. Only add reads that aren’t already listed.")
                    Text("An unknown finish date counts toward All time totals, but not date-specific statistics. No pages or reading time are added.")
                    if let error = model.validationError ?? model.saveError {
                        Label(error, systemImage: "exclamationmark.circle")
                            .accessibilityLabel(error)
                    }
                }
                .font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary)
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceSecondary)
            .navigationTitle("Add past read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save(bookID: bookID, library: libraryStore) { dismiss() }
                    }
                    .disabled(model.validationError != nil)
                }
            }
            .tint(Color.appAccent)
        }
    }
}
