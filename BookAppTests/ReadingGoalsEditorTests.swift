import Foundation
import Testing
@testable import Book_App

@MainActor
struct ReadingGoalsEditorTests {
    @Test func savesMultipleTargetsAndPreservesUneditedLatestGoals() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalJSONRepository<[ReadingGoal]>(fileName: "goals.json", directory: directory)
        let now = Date()
        let model = ReadingGoalsEditorModel(date: now, repository: repository)
        let books = try #require(model.fields.first { $0.period == .year && $0.metric == .books })
        let pages = try #require(model.fields.first { $0.period == .month && $0.metric == .pages })
        let days = try #require(model.fields.first { $0.period == .week && $0.metric == .days })
        var downloadedGoal = days.goal
        downloadedGoal.target = 5
        try repository.save([downloadedGoal, ReadingGoal(year: 2000, target: 12)])
        model.drafts[books.id] = "30"
        model.drafts[pages.id] = "900"
        #expect(model.save())
        let saved = try repository.load(default: [])
        #expect(saved.first { $0.id == books.id }?.target == 30)
        #expect(saved.first { $0.id == pages.id }?.target == 900)
        #expect(saved.first { $0.id == days.id }?.target == 5)
        #expect(saved.first { $0.id == "2000" }?.target == 12)
    }

    @Test func invalidDraftPreventsAllWritesAndClearingRemovesOnlyEditedGoal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalJSONRepository<[ReadingGoal]>(fileName: "goals.json", directory: directory)
        let now = Date()
        let existing = InsightGoalModel.goal(period: .year, metric: .books, date: now, target: 30, calendar: .current)
        try repository.save([existing])
        let model = ReadingGoalsEditorModel(date: now, repository: repository)
        let pages = try #require(model.fields.first { $0.period == .month && $0.metric == .pages })
        model.drafts[existing.id] = "40"
        model.drafts[pages.id] = "0"
        #expect(!model.save())
        #expect(try repository.load(default: []) == [existing])
        model.drafts[pages.id] = ""
        model.drafts[existing.id] = ""
        #expect(model.save())
        #expect(try repository.load(default: []).isEmpty)
    }

    @Test func failedSaveKeepsDraftsForRetry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let scope = AccountStorageScope(directory: directory)
        let model = ReadingGoalsEditorModel(date: Date(), repository: .init(fileName: "goals.json", scope: scope))
        let field = try #require(model.fields.first)
        model.drafts[field.id] = "25"
        scope.invalidate()
        #expect(!model.save())
        #expect(model.drafts[field.id] == "25")
        #expect(model.hasChanges)
        #expect(model.error != nil)
    }
}
