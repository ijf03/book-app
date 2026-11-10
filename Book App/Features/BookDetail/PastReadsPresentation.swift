import Foundation

@MainActor
enum PastReadsPresentation {
    struct Row: Identifiable {
        let id: String
        let dates: String
        let usesSessionStart: Bool
    }

    static func rows(book: Book, sessions: [ReadingSession]) -> [Row] {
        var reads = book.pastReads ?? []
        if book.status == .completed {
            reads.append(PastRead(id: book.currentReadID ?? "initial", startedAt: book.currentReadStartedAt,
                                  completedAt: book.completedAt, format: book.format, progress: book.progress))
        }
        return reads.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.map { read in
            let recordedStart = sessions.filter {
                $0.bookID == book.id && ($0.readID ?? "initial") == read.id &&
                $0.endedAt != nil && $0.startedAt <= (read.completedAt ?? .distantPast)
            }.map(\.startedAt).min()
            let start = read.startedAt ?? recordedStart
            let startText = start?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "Start not recorded")
            let endText = read.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "Finish not recorded")
            return Row(id: read.id, dates: "\(startText) – \(endText)", usesSessionStart: read.startedAt == nil && recordedStart != nil)
        }
    }
}
