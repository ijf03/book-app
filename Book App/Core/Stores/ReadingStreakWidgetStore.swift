import Foundation
import WidgetKit

/// A small, device-local snapshot. No account identifiers or book details leave the app.
@MainActor
enum ReadingStreakWidgetStore {
    static let groupID = "group.edu.monash.BookApp"
    static let snapshotKey = "readingStreakSnapshot"
    static let kind = "ReadingStreakWidget"

    static func snapshot(sessions: [ReadingSession], checkIns: [ReadingCheckIn],
                         now: Date = Date(), calendar: Calendar = .current) -> [String: Any] {
        let events = sessions.compactMap { session -> ReadingStatistics.SessionEvent? in
            guard let end = session.endedAt, end <= now, end >= session.startedAt,
                  session.totalPausedSeconds >= 0 else { return nil }
            return .init(id: session.id, bookID: session.bookID, start: session.startedAt,
                         end: end, seconds: session.elapsedSeconds(at: end), pages: nil)
        }
        let days = ReadingDayCalculator.days(events: events, checkIns: checkIns, calendar: calendar, now: now)
        var value: [String: Any] = [
            "signedIn": true,
            "streak": ReadingDayCalculator.currentStreak(days: days, calendar: calendar, now: now)
        ]
        if let last = days.max() { value["lastReadingDay"] = last }
        return value
    }

    static func publish(sessions: [ReadingSession], checkIns: [ReadingCheckIn]) {
        save(snapshot(sessions: sessions, checkIns: checkIns))
    }

    static func clear() {
        save(["signedIn": false, "streak": 0])
    }

    private static func save(_ value: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }
        if let previous = defaults.dictionary(forKey: snapshotKey),
           NSDictionary(dictionary: previous).isEqual(to: value) { return }
        defaults.set(value, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
