import SwiftUI

struct ProgressNoteSection: View {
    @Bindable var draft: ProgressNoteDraft

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Toggle("Add a note", isOn: $draft.isEnabled)
                    .font(AppTypography.headline)
                    .tint(Color.appAccent)
                    .accessibilityIdentifier("progress.addNote")
                if draft.isEnabled {
                    TextField("What would you like to remember?", text: $draft.text, axis: .vertical)
                        .lineLimit(4...8)
                        .font(AppTypography.body)
                        .accessibilityLabel("Reading note")
                        .accessibilityIdentifier("progress.noteText")
                    Toggle("Contains spoilers", isOn: $draft.containsSpoilers)
                        .tint(Color.appAccent)
                        .accessibilityIdentifier("progress.noteSpoilers")
                    Text("Saved with your progress to this book’s Notes, using the page entered above when available.")
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                if let error = draft.errorMessage {
                    Text(error).font(AppTypography.body).foregroundStyle(Color.danger)
                }
            }
        }
    }
}

#Preview {
    ProgressNoteSection(draft: ProgressNoteDraft())
        .padding(AppSpacing.md)
}
