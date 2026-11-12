import SwiftUI
import Observation

@MainActor @Observable
final class ReadingGoalsEditorModel {
    struct Field: Identifiable {
        let period: InsightGoalPeriod
        let metric: InsightGoalMetric
        let goal: ReadingGoal
        var id: String { goal.id }
    }

    let fields: [Field]
    let date: Date
    let calendar: Calendar
    var drafts: [String: String] = [:]
    private(set) var original: [String: String] = [:]
    private(set) var loaded = false
    private(set) var error: String?
    private let repository: LocalJSONRepository<[ReadingGoal]>

    init(date: Date, repository: LocalJSONRepository<[ReadingGoal]>, calendar: Calendar = .current) {
        self.date = date
        self.calendar = calendar
        self.repository = repository
        fields = InsightGoalPeriod.allCases.flatMap { period in
            InsightGoalMetric.allCases.map { metric in
                Field(period: period, metric: metric,
                      goal: InsightGoalModel.goal(period: period, metric: metric, date: date, target: 1, calendar: calendar))
            }
        }
        load()
    }

    var hasChanges: Bool { drafts != original }
    var isValid: Bool {
        fields.allSatisfy { field in
            let text = drafts[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty || ReadingGoalsViewModel.validTarget(text) != nil
        }
    }

    func load() {
        do {
            let goals = try repository.load(default: [])
            drafts = Dictionary(uniqueKeysWithValues: fields.map { field in
                (field.id, goals.first { $0.id == field.id }.map { String($0.target) } ?? "")
            })
            original = drafts
            loaded = true
            error = nil
        } catch {
            loaded = false
            self.error = String(localized: "Goals couldn’t be loaded. Your saved goals are unchanged.")
        }
    }

    func save() -> Bool {
        guard loaded, isValid else { return false }
        do {
            // Merge only edited targets into the latest data, retaining other periods and cloud updates.
            var goals = try repository.load(default: [])
            for field in fields where drafts[field.id] != original[field.id] {
                goals.removeAll { $0.id == field.id }
                let text = drafts[field.id, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                if let target = ReadingGoalsViewModel.validTarget(text) {
                    var goal = field.goal
                    goal.target = target
                    goals.append(goal)
                }
            }
            try repository.save(goals)
            original = drafts
            error = nil
            return true
        } catch {
            self.error = String(localized: "Your goals couldn’t be saved. Your changes are still here. Please retry.")
            return false
        }
    }
}

struct ReadingGoalsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ReadingGoalsEditorModel
    @FocusState private var focusedField: String?
    @State private var confirmsDiscard = false
    let onSaved: () -> Void

    init(date: Date, repository: LocalJSONRepository<[ReadingGoal]>, onSaved: @escaping () -> Void) {
        _model = State(initialValue: ReadingGoalsEditorModel(date: date, repository: repository))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(InsightGoalPeriod.allCases) { period in
                    Section {
                        ForEach(model.fields.filter { $0.period == period }) { field in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(field.metric.title).font(AppTypography.headline)
                                TextField("No goal", text: Binding(
                                    get: { model.drafts[field.id, default: ""] },
                                    set: { model.drafts[field.id] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: field.id)
                                .accessibilityLabel(Text(field.metric.title))
                                .accessibilityHint(Text(period.title))
                                if let text = model.drafts[field.id], !text.isEmpty,
                                   ReadingGoalsViewModel.validTarget(text) == nil {
                                    Text("Enter a whole number from 1 to 10,000.")
                                        .font(AppTypography.caption).foregroundStyle(Color.danger)
                                }
                            }
                            .padding(.vertical, AppSpacing.xs)
                        }
                    } header: {
                        Text(period.title)
                    } footer: {
                        if let interval = model.calendar.dateInterval(of: period.component, for: model.date),
                           let end = model.calendar.date(byAdding: .day, value: -1, to: interval.end) {
                            Text("\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
                Section {
                    if let error = model.error {
                        Text(error).foregroundStyle(Color.danger)
                        if !model.loaded { Button("Retry loading", action: model.load) }
                    }
                } footer: {
                    Text("Set any goals you want. Leave unused targets blank, or clear an existing target to remove it. Pages count new page coverage in finished sessions. Active days include check-ins or recorded reading time.")
                }
            }
            .disabled(!model.loaded && model.error == nil)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color.surfaceSecondary)
            .navigationTitle("Edit goals")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(model.hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if model.hasChanges { confirmsDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save all") {
                        focusedField = nil
                        if model.save() { onSaved(); dismiss() }
                    }
                    .disabled(!model.loaded || !model.isValid || !model.hasChanges)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .confirmationDialog("Discard your goal changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .tint(Color.appAccent)
        }
    }
}

#Preview("Edit all reading goals") {
    ReadingGoalsEditor(date: .now,
                       repository: .init(fileName: "reading-goals.json",
                                         directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))) {}
}
