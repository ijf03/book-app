import Foundation
import Observation

nonisolated struct ReaderProfile: Codable, Equatable, Sendable {
    var username: String
    var preferredName: String?
    var bio: String?

    var displayName: String { preferredName ?? username }
    var validationError: String? {
        guard username.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil else {
            return String(localized: "Use 3–24 letters, numbers or underscores for your username.")
        }
        guard (preferredName?.count ?? 0) <= 60, (bio?.count ?? 0) <= 240 else {
            return String(localized: "Keep your preferred name under 61 characters and your bio under 241 characters.")
        }
        return nil
    }

    static func draft(username: String, preferredName: String, bio: String) -> Self {
        func optional(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return .init(username: username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                     preferredName: optional(preferredName), bio: optional(bio))
    }
}

@MainActor @Observable
final class ReaderProfileStore {
    private(set) var profile: ReaderProfile?
    private(set) var error: String?
    private let scope: AccountStorageScope?
    private let repository: LocalJSONRepository<[ReaderProfile]>

    init(scope: AccountStorageScope?) {
        self.scope = scope
        repository = .init(fileName: "reader-profile.json", scope: scope)
        reload()
    }

    func reload() {
        guard scope?.isActive != false else { clear(); return }
        do {
            let values = try repository.load(default: [])
            guard values.count <= 1, values.allSatisfy({ $0.validationError == nil }) else { throw CocoaError(.coderReadCorrupt) }
            profile = values.first
            error = nil
        } catch {
            self.error = String(localized: "Your profile couldn’t be loaded. Please retry.")
        }
    }

    var needsWelcome: Bool { scope?.isActive != false && profile == nil && error == nil }

    func clear() { profile = nil; error = nil }

    func save(_ value: ReaderProfile, onlyIfMissing: Bool = false) -> Bool {
        guard scope?.isActive != false else { return false }
        guard value.validationError == nil else { error = value.validationError; return false }
        reload()
        guard error == nil else { return false }
        // An existing profile may arrive from another device while welcome is open.
        if onlyIfMissing && profile != nil { return true }
        do {
            try repository.save([value])
            profile = value
            error = nil
            return true
        } catch {
            self.error = String(localized: "Your profile couldn’t be saved. Please retry.")
            return false
        }
    }
}
