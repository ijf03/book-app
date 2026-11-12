import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingStreakWidgetTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test func sessionsAndCheckInsShareOneStreakWithoutDoubleCounting() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let session = ReadingSession(bookID: "widget-check", startedAt: today,
                                     endedAt: today.addingTimeInterval(60), startProgress: .empty)
        let checkIns = [today, yesterday].map {
            ReadingCheckIn(day: ReadingCheckIn.dayKey($0, calendar: calendar),
                           didRead: true, recordedAt: $0)
        }
        let result = ReadingStreakWidgetStore.snapshot(sessions: [session], checkIns: checkIns,
                                                      now: now, calendar: calendar)
        #expect(result["streak"] as? Int == 2)
        #expect(result["lastReadingDay"] as? Date == today)
        #expect(result["signedIn"] as? Bool == true)
        #expect(Set(result.keys) == ["signedIn", "streak", "lastReadingDay"])
    }

    @Test func unfinishedAndFullyPausedSessionsDoNotMarkTodayRead() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let start = now.addingTimeInterval(-60)
        let active = ReadingSession(bookID: "active", startedAt: start, startProgress: .empty)
        let paused = ReadingSession(bookID: "paused", startedAt: start, endedAt: now,
                                    totalPausedSeconds: 60, startProgress: .empty)
        let result = ReadingStreakWidgetStore.snapshot(sessions: [active, paused], checkIns: [],
                                                      now: now, calendar: calendar)
        #expect(result["streak"] as? Int == 0)
        #expect(result["lastReadingDay"] == nil)
    }
}
