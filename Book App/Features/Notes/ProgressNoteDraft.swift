import Foundation
import Observation

@MainActor
@Observable
final class ProgressNoteDraft {
    var isEnabled = false
    var text = ""
    var containsSpoilers = false
    private(set) var errorMessage: LocalizedStringResource?
    private let id = UUID()
    private let createdAt = Date()

    var canSave: Bool {
        !isEnabled || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A stable draft ID makes a repeated save update the same note, rather than duplicate it.
    func save(bookID: String, page: Int?, to store: BookContentStore?) -> Bool {
        errorMessage = nil
        guard isEnabled else { return true }
        guard canSave else {
            errorMessage = "Write a note or turn off Add a note."
            return false
        }
        let note = ReadingNote(id: id, bookID: bookID,
                               text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                               page: page, containsSpoilers: containsSpoilers,
                               createdAt: createdAt, updatedAt: Date())
        guard let store, store.saveProgressNote(note) else {
            errorMessage = "Your note couldn’t be saved. Your draft is still here. Please try again."
            return false
        }
        return true
    }
}
