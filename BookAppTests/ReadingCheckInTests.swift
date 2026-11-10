import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingCheckInTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private let now = ISO8601DateFormatter().date(from: "2026-11-10T12:00:00Z")!

    @Test func repeatedCheckInPersistsOnceAndDoesNotFabricateSessionMetrics() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let store = ReadingCheckInStore(scope: scope)
        #expect(store.setToday(didRead: true, now: now, calendar: calendar))
        #expect(store.setToday(didRead: true, now: now, calendar: calendar))
        #expect(store.entries.count == 1)
        let reopened = ReadingCheckInStore(scope: scope)
        #expect(reopened.entries == store.entries)
        var input = StatisticsInput()
        input.checkIns = reopened.entries
        let stats = ReadingStatisticsCalculator.calculate(input, selection: .init(from: now, to: now), calendar: calendar, now: now)
        #expect(stats.activeDays.count == 1)
        #expect(stats.seconds == 0 && stats.pages == 0 && stats.sessions == 0)
        #expect(stats.hasData)
        let insights = ReadingInsightsCalculator.calculate(input, statistics: stats, calendar: calendar, now: now)
        #expect(insights.currentStreak == 1 && insights.longestStreak == 1)
        #expect(insights.months.last?.activeDays == 1)
    }

    @Test func noAnswerCannotEraseSessionsAndUnionCountsEachDayOnce() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let events: [ReadingStatistics.SessionEvent] = [
            .init(id: UUID(), bookID: "one", start: now.addingTimeInterval(-60), end: now, seconds: 60, pages: 1)
        ]
        let checkIns = [
            ReadingCheckIn(day: ReadingCheckIn.dayKey(yesterday, calendar: calendar), didRead: true, recordedAt: yesterday),
            ReadingCheckIn(day: ReadingCheckIn.dayKey(now, calendar: calendar), didRead: false, recordedAt: now)
        ]
        let days = ReadingDayCalculator.days(events: events, checkIns: checkIns, calendar: calendar, now: now)
        #expect(days.count == 2)
        #expect(ReadingDayCalculator.currentStreak(days: days, calendar: calendar, now: now) == 2)
        #expect(ReadingDayCalculator.days(events: [], checkIns: checkIns, calendar: calendar, now: now).count == 1)
        let yes = ReadingCheckIn(day: checkIns[1].day, didRead: true, recordedAt: now)
        #expect(ReadingDayCalculator.days(events: events, checkIns: [yes], calendar: calendar, now: now).count == 1)
    }

    @Test func dateBoundariesAndFutureDaysDoNotExtendStreak() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let checkIns = [yesterday, now, tomorrow].map {
            ReadingCheckIn(day: ReadingCheckIn.dayKey($0, calendar: calendar), didRead: true, recordedAt: $0)
        }
        let interval = DateInterval(start: calendar.startOfDay(for: now), end: calendar.startOfDay(for: tomorrow))
        let days = ReadingDayCalculator.days(events: [], checkIns: checkIns, calendar: calendar, now: now, interval: interval)
        #expect(days == [calendar.startOfDay(for: now)])
        #expect(ReadingDayCalculator.currentStreak(days: days, calendar: calendar, now: tomorrow) == 1)
        let afterGap = calendar.date(byAdding: .day, value: 2, to: now)!
        #expect(ReadingDayCalculator.currentStreak(days: days, calendar: calendar, now: afterGap) == 0)
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        #expect(ReadingCheckIn.dayKey(now, calendar: buddhist) == "2026-11-10")
        #expect(checkIns[1].date(calendar: buddhist) == calendar.startOfDay(for: now))
    }

    @Test func undoAndAccountSwitchPreserveIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let store = ReadingCheckInStore(scope: scope)
        #expect(store.setToday(didRead: true, now: now, calendar: calendar))
        #expect(store.setToday(didRead: false, now: now, calendar: calendar))
        #expect(store.entries.count == 1 && store.entries.first?.didRead == false)
        scope.invalidate()
        store.clear()
        #expect(!store.setToday(didRead: true, now: now, calendar: calendar))
        #expect(store.entries.isEmpty)
        let other = ReadingCheckInStore(scope: AccountStorageScope(directory: directory.appendingPathComponent("B")))
        #expect(other.entries.isEmpty)
    }

    @Test func offlineJournalSurvivesRestartAndProjectsOnAnotherDevice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstScope = AccountStorageScope(directory: root.appendingPathComponent("one"))
        let first = try LocalSyncRepository(userID: "A", scope: firstScope)
        firstScope.syncRepository = first
        let store = ReadingCheckInStore(scope: firstScope)
        #expect(store.setToday(didRead: true, now: now, calendar: calendar))
        let pending = try #require(first.pending.first { $0.entityID == "checkIn-2026-11-10" })
        let reopened = try LocalSyncRepository(userID: "A", scope: firstScope)
        #expect(reopened.pending.first?.operationID == pending.operationID)
        let secondScope = AccountStorageScope(directory: root.appendingPathComponent("two"))
        let second = try LocalSyncRepository(userID: "A", scope: secondScope)
        secondScope.syncRepository = second
        // Exercise the same validated journal/projection path used by downloaded documents.
        try second.receive(first.records)
        let downloaded = ReadingCheckInStore(scope: secondScope)
        #expect(downloaded.entries == store.entries)
        let reminders = try second.data(for: "reading-reminders.json")
        #expect(try JSONDecoder().decode(ReadingReminderPreferences.self, from: reminders) == ReadingReminderPreferences())
    }

    @Test func corruptLocalCheckInsArePreservedRatherThanOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("reading-check-ins.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: file)
        let store = ReadingCheckInStore(scope: AccountStorageScope(directory: directory))
        #expect(!store.setToday(didRead: true, now: now, calendar: calendar))
        #expect(store.error != nil)
        #expect(try Data(contentsOf: file) == corrupt)
    }
}
