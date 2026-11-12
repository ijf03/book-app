import Foundation
import Observation

nonisolated struct ReviewMood: Codable, Hashable, Sendable {
    let name: String
    var id: String { "mood-" + name.lowercased() }
    var isValid: Bool { !name.isEmpty && name.count <= 100 && name == name.trimmingCharacters(in: .whitespacesAndNewlines) }
    static let presets = ["Happy", "Hopeful", "Inspired", "Reflective", "Comforted", "Excited", "Sad", "Anxious", "Angry", "Disappointed", "Surprised", "Bittersweet"]
    static func displayName(_ name: String) -> String {
        switch name {
        case "Happy": String(localized: "Happy")
        case "Hopeful": String(localized: "Hopeful")
        case "Inspired": String(localized: "Inspired")
        case "Reflective": String(localized: "Reflective")
        case "Comforted": String(localized: "Comforted")
        case "Excited": String(localized: "Excited")
        case "Sad": String(localized: "Sad")
        case "Anxious": String(localized: "Anxious")
        case "Angry": String(localized: "Angry")
        case "Disappointed": String(localized: "Disappointed")
        case "Surprised": String(localized: "Surprised")
        case "Bittersweet": String(localized: "Bittersweet")
        default: name
        }
    }
    static func normalize(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor @Observable
final class ReviewMoodStore {
    private(set) var saved: [ReviewMood] = []
    private(set) var error: String?
    private let scope: AccountStorageScope?
    private let repository: LocalJSONRepository<[ReviewMood]>
    init(scope: AccountStorageScope?) {
        self.scope = scope
        repository = .init(fileName: "review-moods.json", scope: scope)
        reload()
    }
    func clear() { saved = []; error = nil }
    func reload() {
        guard scope?.isActive != false else { clear(); return }
        do {
            let values = try repository.load(default: [])
            guard values.allSatisfy(\.isValid) else { throw CocoaError(.coderReadCorrupt) }
            saved = values
            error = nil
        } catch { self.error = String(localized: "Your saved moods couldn’t load. Please retry.") }
    }
    func choices(reviews: [BookReview], selected: String) -> [String] {
        var seen = Set<String>()
        return (ReviewMood.presets + saved.map(\.name) + reviews.compactMap(\.mood) + [selected])
            .map(ReviewMood.normalize).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
    func remember(_ text: String) -> String? {
        guard scope?.isActive != false else { return nil }
        let mood = ReviewMood(name: ReviewMood.normalize(text))
        guard mood.isValid else { error = String(localized: "Enter a mood using 1–100 characters."); return nil }
        reload()
        guard error == nil else { return nil }
        if let existing = (ReviewMood.presets + saved.map(\.name)).first(where: { $0.lowercased() == mood.name.lowercased() }) { return existing }
        do {
            try repository.save(saved + [mood])
            saved.append(mood)
            return mood.name
        } catch { self.error = String(localized: "Your mood couldn’t be saved. Please retry."); return nil }
    }
}
