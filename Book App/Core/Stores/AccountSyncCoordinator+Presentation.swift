import Foundation

extension AccountSyncCoordinator {
    var statusText: String {
        switch phase {
        case .locallySaved: String(localized: "Saved locally · waiting for cloud")
        case .pending: String(localized: "Saved locally · \(local.pendingCount) pending uploads")
        case .syncing: String(localized: "Syncing · \(local.pendingCount) pending uploads")
        case .confirmed:
            local.conflicts.isEmpty ? String(localized: "Cloud sync confirmed") : String(localized: "Synced · conflicting edits need review")
        case .failed(let message): message
        case .stopped: String(localized: "Sync stopped")
        }
    }

    var statusSymbol: String {
        switch phase {
        case .confirmed: local.conflicts.isEmpty ? "checkmark.icloud" : "exclamationmark.icloud"
        case .failed: "exclamationmark.icloud"
        case .syncing: "arrow.triangle.2.circlepath"
        case .locallySaved, .pending, .stopped: "icloud.slash"
        }
    }

    func conflictTitle(_ conflict: LocalSyncRepository.Conflict) -> String {
        switch conflict.rejected.collection {
        case .books: String(localized: "Book")
        case .sessions: String(localized: "Reading session")
        case .notes: String(localized: "Note")
        case .reviews: String(localized: "Review")
        case .goals: String(localized: "Reading goal")
        case .lists: String(localized: "Custom list")
        case .preferences: String(localized: "Preferences or ordering")
        }
    }

    func conflictSummary(_ conflict: LocalSyncRepository.Conflict) -> String? {
        guard let payload = conflict.rejected.payload,
              let fields = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return nil }
        return fields["title"] as? String ?? fields["name"] as? String ?? fields["text"] as? String
    }
}
