import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String

    var title: String
    var authors: [String]
    var description: String?
    var coverURL: URL?

    var pageCount: Int?
    var status: ReadingStatus
    var format: ReadingFormat

    // Preserve local identity for existing notes and sessions.
    var sourceBookID: String? = nil
    var completedAt: Date? = nil
    // Optional for backwards-compatible decoding of existing account libraries.
    var genre: String? = nil
    var bookType: String? = nil // fiction or nonfiction; nil means unrecorded
    var language: String? = nil
    var progress: ReadingProgress = .empty
    var pastReads: [PastRead]? = nil
    var currentReadID: String? = nil
    var currentReadStartedAt: Date? = nil

    var completedReadCount: Int { (pastReads?.count ?? 0) + (status == .completed ? 1 : 0) }

    /// Nil IDs on existing books and sessions identify the original read.
    mutating func beginReread(at date: Date = Date()) {
        guard status == .completed else { return }
        var history = pastReads ?? []
        let readID = currentReadID ?? "initial"
        if !history.contains(where: { $0.id == readID }) {
            history.append(PastRead(id: readID, startedAt: currentReadStartedAt,
                                    completedAt: completedAt, format: format, progress: progress))
        }
        pastReads = history
        currentReadID = UUID().uuidString
        currentReadStartedAt = date
        completedAt = nil
        status = .reading
        progress = ReadingProgress(page: 0, percentage: 0, timestampSeconds: 0)
    }

    var authorText: String {
        authors.joined(separator: ", ")
    }
}

/// A completed reading cycle. Missing legacy dates stay unknown, never inferred from today.
struct PastRead: Identifiable, Codable, Hashable {
    static func validation(start: Date?, end: Date?, now: Date = Date()) -> String? {
        if [start, end].compactMap({ $0 }).contains(where: { !$0.timeIntervalSinceReferenceDate.isFinite || $0 > now }) {
            return String(localized: "Choose dates on or before today.")
        }
        if let start, let end, start > end {
            return String(localized: "Start date must be on or before finish date.")
        }
        return nil
    }

    let id: String
    let startedAt: Date?
    let completedAt: Date?
    let format: ReadingFormat
    let progress: ReadingProgress
}
