import Foundation

/// One mapping for every persisted field. Dates retain Foundation's JSON epoch
/// (seconds since 2001-01-01); URLs remain strings. No derived statistics are stored.
@MainActor
enum SyncEntityCodec {
    struct Entity {
        let collection: SyncCollection
        let id: String
        let payload: Data
        var key: String { collection.rawValue + "/" + CloudRecord.documentID(for: id) }
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func entities(file: String, data: Data) throws -> [Entity] {
        let decoder = JSONDecoder()
        switch file {
        case "review-moods.json":
            return try decoder.decode([ReviewMood].self, from: data).map {
                Entity(collection: .preferences, id: $0.id, payload: try encode($0))
            }
        case "reader-profile.json":
            let values = try decoder.decode([ReaderProfile].self, from: data)
            guard values.count <= 1 else { throw SyncFailure.malformed }
            return try values.map { Entity(collection: .preferences, id: "readerProfile", payload: try encode($0)) }
        case "library.json":
            let values = try decoder.decode([Book].self, from: data)
            var result = try values.map { Entity(collection: .books, id: $0.id, payload: try encode($0)) }
            result.append(Entity(collection: .preferences, id: "bookOrder", payload: try encode(Order(ids: values.map(\.id)))))
            return result
        case "reading-check-ins.json":
            return try decoder.decode([ReadingCheckIn].self, from: data).map {
                Entity(collection: .preferences, id: $0.id, payload: try encode($0))
            }
        case "reading-sessions.json":
            return try decoder.decode([ReadingSession].self, from: data).map {
                Entity(collection: .sessions, id: $0.id.uuidString, payload: try encode($0))
            }
        case "book-content.json":
            let content = try decoder.decode(BookContentData.self, from: data)
            return try content.notes.map { Entity(collection: .notes, id: $0.id.uuidString, payload: try encode($0)) } +
                content.reviews.map { Entity(collection: .reviews, id: $0.bookID, payload: try encode($0)) }
        case "reading-goals.json":
            return try decoder.decode([ReadingGoal].self, from: data).map {
                Entity(collection: .goals, id: $0.id, payload: try encode($0))
            }
        case "custom-book-lists.json":
            let values = try decoder.decode([CustomBookList].self, from: data)
            var result = try values.map { Entity(collection: .lists, id: $0.id.uuidString, payload: try encode($0)) }
            result.append(Entity(collection: .preferences, id: "listOrder", payload: try encode(Order(ids: values.map { $0.id.uuidString }))))
            return result
        case "reading-reminders.json":
            return [Entity(collection: .preferences, id: "reminders",
                           payload: try encode(decoder.decode(ReadingReminderPreferences.self, from: data)))]
        default: throw SyncFailure.malformed
        }
    }

    static func file(for collection: SyncCollection, id: String) -> String {
        switch collection {
        case .books: "library.json"
        case .sessions: "reading-sessions.json"
        case .notes, .reviews: "book-content.json"
        case .goals: "reading-goals.json"
        case .lists: "custom-book-lists.json"
        case .preferences:
            id.hasPrefix("mood-") ? "review-moods.json" : id == "readerProfile" ? "reader-profile.json" : id.hasPrefix("checkIn-") ? "reading-check-ins.json" : id == "bookOrder" ? "library.json" : id == "listOrder" ? "custom-book-lists.json" : "reading-reminders.json"
        }
    }

    static func validate(_ record: CloudRecord) throws {
        guard record.schemaVersion == 1, record.revision > 0,
              !record.entityID.isEmpty, record.entityID.utf8.count <= 4096,
              !record.operationID.isEmpty else { throw SyncFailure.malformed }
        guard let data = record.payload else { return }
        guard data.count <= 800_000 else { throw SyncFailure.malformed }
        let decoder = JSONDecoder()
        let identity: String
        switch record.collection {
        case .books:
            let value = try decoder.decode(Book.self, from: data)
            guard (value.genres?.count ?? 0) <= 30,
                  value.genres?.allSatisfy({ !$0.isEmpty && $0.count <= 100 }) ?? true,
                  value.metadata?.isValid ?? true else { throw SyncFailure.malformed }
            guard value.genre.map({ $0.count <= 100 }) ?? true else { throw SyncFailure.malformed }
            guard value.language.map({ $0.count <= 100 }) ?? true,
                  value.bookType.map({ ["fiction", "nonfiction"].contains($0) }) ?? true else { throw SyncFailure.malformed }
            guard value.currentReadID.map({ !$0.isEmpty && $0.count <= 100 }) ?? true,
                  value.currentReadStartedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else { throw SyncFailure.malformed }
            guard value.immersiveReadingPercentage.map({ $0.isFinite && (0...100).contains($0) }) ?? true,
                  value.immersiveCompanion.map({ $0 == .physical || $0 == .ebook }) ?? true,
                  value.audioDurationSeconds.map({ $0 > 0 && $0 <= 360_003_599 }) ?? true,
                  value.abandonedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true,
                  (value.formatsUsed?.count ?? 0) <= 4 else { throw SyncFailure.malformed }
            let reads = value.pastReads ?? []
            guard reads.count <= 10000, Set(reads.map(\.id)).count == reads.count,
                  !reads.contains(where: { $0.id == (value.currentReadID ?? "initial") }) else { throw SyncFailure.malformed }
            for read in reads {
                guard !read.id.isEmpty, read.id.count <= 100,
                      read.startedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true,
                      read.completedAt.map({ $0.timeIntervalSinceReferenceDate.isFinite }) ?? true else { throw SyncFailure.malformed }
                if let start = read.startedAt, let end = read.completedAt, start > end { throw SyncFailure.malformed }
                try validateProgress(read.progress)
            }
            identity = value.id
            try validateProgress(value.progress)
        case .sessions:
            let value = try decoder.decode(ReadingSession.self, from: data)
            guard !value.bookID.isEmpty, value.totalPausedSeconds >= 0,
                  value.readID.map({ !$0.isEmpty && $0.count <= 100 }) ?? true else { throw SyncFailure.malformed }
            guard (value.formats?.count ?? 0) <= 4 else { throw SyncFailure.malformed }
            try validateProgress(value.startProgress)
            if let progress = value.endProgress { try validateProgress(progress) }
            identity = value.id.uuidString
        case .notes:
            let value = try decoder.decode(ReadingNote.self, from: data)
            guard !value.bookID.isEmpty else { throw SyncFailure.malformed }
            identity = value.id.uuidString
        case .reviews:
            let value = try decoder.decode(BookReview.self, from: data)
            guard (1...5).contains(value.rating), value.mood.map({ $0.count <= 100 }) ?? true else { throw SyncFailure.malformed }
            identity = value.bookID
        case .goals:
            let value = try decoder.decode(ReadingGoal.self, from: data)
            guard (1...9999).contains(value.year), (1...10000).contains(value.target) else { throw SyncFailure.malformed }
            guard (value.period == nil && value.metric == nil && value.periodKey == nil)
                || (["year", "month", "week"].contains(value.period ?? "")
                    && ["books", "pages", "days"].contains(value.metric ?? "")
                    && !(value.periodKey ?? "").isEmpty) else { throw SyncFailure.malformed }
            identity = value.id
        case .lists:
            identity = try decoder.decode(CustomBookList.self, from: data).id.uuidString
        case .preferences:
            if record.entityID.hasPrefix("mood-") {
                let mood = try decoder.decode(ReviewMood.self, from: data)
                guard mood.isValid, mood.id == record.entityID else { throw SyncFailure.malformed }
            } else if record.entityID == "readerProfile" {
                guard try decoder.decode(ReaderProfile.self, from: data).validationError == nil else { throw SyncFailure.malformed }
            } else if record.entityID.hasPrefix("checkIn-") {
                let value = try decoder.decode(ReadingCheckIn.self, from: data)
                guard value.id == record.entityID, value.date(calendar: Calendar(identifier: .gregorian)) != nil,
                      value.recordedAt.timeIntervalSinceReferenceDate.isFinite else { throw SyncFailure.malformed }
            } else if record.entityID == "reminders" {
                guard try decoder.decode(ReadingReminderPreferences.self, from: data).isValid else { throw SyncFailure.malformed }
            } else if ["bookOrder", "listOrder"].contains(record.entityID) {
                _ = try decoder.decode(Order.self, from: data)
            } else { throw SyncFailure.malformed }
            identity = record.entityID
        }
        guard identity == record.entityID else { throw SyncFailure.malformed }
    }

    private static func validateProgress(_ value: ReadingProgress) throws {
        guard value.page.map({ $0 >= 0 }) ?? true,
              value.timestampSeconds.map({ $0 >= 0 }) ?? true,
              value.percentage.map({ $0.isFinite && (0...100).contains($0) }) ?? true else { throw SyncFailure.malformed }
    }

    static func projection(file: String, records: [CloudRecord]) throws -> Data {
        let live = records.filter { !$0.isDeleted }
        func values<T: Decodable>(_ collection: SyncCollection, _: T.Type) throws -> [T] {
            try live.filter { $0.collection == collection }.sorted { $0.entityID < $1.entityID }
                .compactMap { record in
                    guard let payload = record.payload else { return nil }
                    return try JSONDecoder().decode(T.self, from: payload)
                }
        }
        func ordered<T>(_ values: [T], orderID: String, identity: (T) -> String) throws -> [T] {
            let payload = live.first { $0.collection == .preferences && $0.entityID == orderID }?.payload
            let ids = try payload.map { try JSONDecoder().decode(Order.self, from: $0).ids } ?? []
            let positions = Dictionary(ids.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
            return values.sorted {
                let left = positions[identity($0)] ?? Int.max
                let right = positions[identity($1)] ?? Int.max
                return left == right ? identity($0) < identity($1) : left < right
            }
        }
        switch file {
        case "review-moods.json":
            return try encode(live.filter { $0.collection == .preferences && $0.entityID.hasPrefix("mood-") }
                .sorted { $0.entityID < $1.entityID }
                .compactMap { try $0.payload.map { try JSONDecoder().decode(ReviewMood.self, from: $0) } })
        case "reader-profile.json":
            let payload = live.first { $0.collection == .preferences && $0.entityID == "readerProfile" }?.payload
            return try encode(payload.map { [try JSONDecoder().decode(ReaderProfile.self, from: $0)] } ?? [])
        case "library.json":
            return try encode(ordered(values(.books, Book.self), orderID: "bookOrder", identity: { $0.id }))
        case "reading-check-ins.json":
            return try encode(live.filter { $0.collection == .preferences && $0.entityID.hasPrefix("checkIn-") }
                .sorted { $0.entityID < $1.entityID }
                .compactMap { try $0.payload.map { try JSONDecoder().decode(ReadingCheckIn.self, from: $0) } })
        case "reading-sessions.json": return try encode(values(.sessions, ReadingSession.self))
        case "book-content.json":
            return try encode(BookContentData(notes: values(.notes, ReadingNote.self), reviews: values(.reviews, BookReview.self)))
        case "reading-goals.json": return try encode(values(.goals, ReadingGoal.self))
        case "custom-book-lists.json":
            return try encode(ordered(values(.lists, CustomBookList.self), orderID: "listOrder", identity: { $0.id.uuidString }))
        case "reading-reminders.json":
            return try live.first { $0.collection == .preferences && $0.entityID == "reminders" }?.payload
                ?? encode(ReadingReminderPreferences())
        default: throw SyncFailure.malformed
        }
    }

    private struct Order: Codable { let ids: [String] }
}
