import Foundation
import Observation

@MainActor @Observable
final class AddPastReadViewModel {
    var startDate = Date()
    var endDate = Date()
    var startUnknown = false
    var endUnknown = false
    var saveError: String?
    private let entryID = UUID().uuidString

    var start: Date? { startUnknown ? nil : Calendar.current.startOfDay(for: startDate) }
    var end: Date? { endUnknown ? nil : Calendar.current.startOfDay(for: endDate) }

    static func validation(start: Date?, end: Date?, now: Date = Date()) -> String? {
        PastRead.validation(start: start, end: end, now: now)
    }

    var validationError: String? { Self.validation(start: start, end: end) }

    func save(bookID: String, library: LibraryStore) -> Bool {
        guard validationError == nil else { return false }
        let saved = library.addPastRead(bookID: bookID, id: entryID, start: start, end: end)
        saveError = saved ? nil : String(localized: "Couldn’t save this past read. Please try again.")
        return saved
    }
}
