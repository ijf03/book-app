import Foundation
import Observation

nonisolated struct ReadingCheckIn: Codable, Hashable, Identifiable, Sendable {
    var id: String { "checkIn-" + day }
    let day: String
    var didRead: Bool
    var recordedAt: Date

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = calendar.timeZone
        let parts = civil.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func date(calendar: Calendar) -> Date? {
        var civil = Calendar(identifier: .gregorian)
        civil.timeZone = calendar.timeZone
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10,
              let value = civil.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              Self.dayKey(value, calendar: calendar) == day else { return nil }
        return value
    }
}

/// Civil dates are stored independently of sessions: checking in never fabricates time/pages.
@MainActor @Observable
final class ReadingCheckInStore {
    private(set) var entries: [ReadingCheckIn] = []
    private(set) var error: String?
    private let scope: AccountStorageScope?
    private let repository: LocalJSONRepository<[ReadingCheckIn]>

    init(scope: AccountStorageScope?) {
        self.scope = scope
        repository = .init(fileName: "reading-check-ins.json", scope: scope)
        reload()
    }

    func reload() {
        guard scope?.isActive != false else { clear(); return }
        do {
            let loaded = try repository.load(default: [])
            guard Set(loaded.map(\.id)).count == loaded.count,
                  loaded.allSatisfy({ $0.date(calendar: Calendar(identifier: .gregorian)) != nil && $0.recordedAt.timeIntervalSinceReferenceDate.isFinite }) else {
                throw CocoaError(.coderReadCorrupt)
            }
            entries = loaded
            error = nil
        }
        catch { self.error = String(localized: "Your check-ins couldn’t be loaded. Your saved data is preserved. Please retry.") }
    }

    func clear() { entries = []; error = nil }

    @discardableResult
    func setToday(didRead: Bool, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard scope?.isActive != false else { return false }
        // Load the latest journal before editing so other days from cloud are preserved.
        reload()
        guard error == nil else { return false }
        let day = ReadingCheckIn.dayKey(now, calendar: calendar)
        if entries.first(where: { $0.day == day })?.didRead == didRead { return true }
        var updated = entries.filter { $0.day != day }
        updated.append(.init(day: day, didRead: didRead, recordedAt: now))
        do {
            try repository.save(updated)
            entries = updated
            return true
        } catch {
            self.error = String(localized: "Your check-in couldn’t be saved. Please retry.")
            return false
        }
    }
}

nonisolated enum ReadingDayCalculator {
    static func days(events: [ReadingStatistics.SessionEvent], checkIns: [ReadingCheckIn],
                     calendar: Calendar, now: Date, interval: DateInterval? = nil) -> Set<Date> {
        let today = calendar.startOfDay(for: now)
        var days = Set(events.filter { $0.seconds > 0 && $0.end <= now }.map { calendar.startOfDay(for: $0.end) })
        for entry in checkIns where entry.didRead {
            if let date = entry.date(calendar: calendar), date <= today { days.insert(date) }
        }
        if let interval { days = days.filter { $0 >= interval.start && $0 < interval.end } }
        return days
    }

    static func currentStreak(days: Set<Date>, calendar: Calendar, now: Date) -> Int {
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var day = days.contains(today) ? today : yesterday
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
