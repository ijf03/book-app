import Foundation
import Observation
import SwiftUI

struct LocalJSONRepository<Value: Codable> {
    let fileName: String
    var directory: URL? = nil
    private func fileURL() throws -> URL {
        let folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("BookApp", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(fileName)
    }
    func load(default fallback: Value) throws -> Value {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return fallback }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
    func save(_ value: Value) throws { try JSONEncoder().encode(value).write(to: fileURL(), options: .atomic) }
}

struct ReadingGoal: Codable, Identifiable, Equatable {
    var year: Int
    var target: Int
    var id: Int { year }
}

@MainActor @Observable final class ReadingGoalsViewModel {
    private(set) var goals: [ReadingGoal] = []
    var errorMessage: String?
    private(set) var canSave = true
    let library: LibraryStore
    private let repository: LocalJSONRepository<[ReadingGoal]>
    init(library: LibraryStore, repository: LocalJSONRepository<[ReadingGoal]> = .init(fileName: "reading-goals.json")) {
        self.library = library; self.repository = repository; reload()
    }
    func reload() {
        do { goals = try repository.load(default: []); canSave = true; errorMessage = nil }
        catch { canSave = false; errorMessage = "Your goals couldn’t be loaded. The saved file has been preserved. Please try again." }
    }
    static func validTarget(_ text: String) -> Int? {
        guard let target = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), (1...10000).contains(target) else { return nil }
        return target
    }
    func goal(for year: Int) -> ReadingGoal? { goals.first { $0.year == year } }
    func completedBooks(in year: Int, now: Date = Date(), calendar: Calendar = .current) -> Int {
        library.books.filter { $0.status == .completed && calendar.component(.year, from: $0.completedAt ?? now) == year }.count
    }
    @discardableResult func save(year: Int, targetText: String) -> Bool {
        guard canSave, (1...9999).contains(year), let target = Self.validTarget(targetText) else { errorMessage = "Enter a valid year and a target from 1 to 10,000."; return false }
        var updated = goals.filter { $0.year != year }; updated.append(ReadingGoal(year: year, target: target))
        do { try repository.save(updated); goals = updated; errorMessage = nil; return true }
        catch { errorMessage = "Your goal couldn’t be saved. Your previous goal is unchanged."; return false }
    }
}

struct ReadingGoalSection: View {
    @State private var viewModel: ReadingGoalsViewModel
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var isEditing = false
    @State private var targetText = ""
    init(library: LibraryStore) { _viewModel = State(initialValue: ReadingGoalsViewModel(library: library)) }
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Reading Goal")
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Stepper("Year \(String(year))", value: $year, in: 1900...9999).font(AppTypography.headline)
                    if let goal = viewModel.goal(for: year) {
                        let completed = viewModel.completedBooks(in: year)
                        let fraction = min(Double(completed) / Double(max(goal.target, 1)), 1)
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle().stroke(Color.accentTint, lineWidth: 10)
                                Circle().trim(from: 0, to: fraction).stroke(Color.appAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text("\(Int(fraction * 100))%").font(AppTypography.headline)
                            }.frame(width: 92, height: 92)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(completed) of \(goal.target) books completed")
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("\(completed) / \(goal.target) books").font(AppTypography.title)
                                Text("\(max(goal.target - completed, 0)) remaining").font(AppTypography.body).foregroundStyle(Color.textSecondary)
                            }
                        }
                    } else { Text("Set a reading goal for this year.").foregroundStyle(Color.textSecondary) }
                    Button(viewModel.goal(for: year) == nil ? "Set Goal" : "Edit Goal") {
                        targetText = viewModel.goal(for: year).map { String($0.target) } ?? ""; isEditing = true
                    }.buttonStyle(AppButtonStyle(kind: .secondary)).disabled(!viewModel.canSave)
                    if !viewModel.canSave { Button("Retry Loading Goals") { viewModel.reload() } }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                Form {
                    Section("Books to complete in \(String(year))") {
                        TextField("Target number of books", text: $targetText).keyboardType(.numberPad)
                        if ReadingGoalsViewModel.validTarget(targetText) == nil { Text("Enter a whole number from 1 to 10,000.").font(AppTypography.caption).foregroundStyle(Color.textSecondary) }
                    }
                }.navigationTitle("Reading Goal").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isEditing = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Save") { if viewModel.save(year: year, targetText: targetText) { isEditing = false } }.disabled(ReadingGoalsViewModel.validTarget(targetText) == nil) }
                    }
                    .alert("Couldn’t Save Goal", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "Please try again.") }
            }
        }
        .alert("Couldn’t Load Goals", isPresented: Binding(get: { !isEditing && viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage ?? "Please try again.") }
    }
}
