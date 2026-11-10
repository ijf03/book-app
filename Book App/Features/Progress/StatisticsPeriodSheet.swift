import SwiftUI

struct StatisticsPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @State private var draft: StatisticsSelection
    let onApply: (StatisticsSelection) -> Void

    init(selection: StatisticsSelection, onApply: @escaping (StatisticsSelection) -> Void) {
        _draft = State(initialValue: selection)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Use a preset or enter your own date range.")
                    Picker("Period", selection: $draft.period) {
                        ForEach(StatisticsPeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("stats.periodOptions")
                }
                Section("Custom dates") {
                    DatePicker("From", selection: $draft.from, in: ...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("stats.from")
                    DatePicker("To", selection: $draft.to, in: ...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("stats.to")
                    if let message = draft.validation(calendar: calendar, now: Date()) {
                        Text(message).foregroundStyle(Color.danger)
                            .accessibilityIdentifier("stats.dateError")
                    }
                }
            }
            .onChange(of: draft.from) { _, _ in draft.period = .custom }
            .onChange(of: draft.to) { _, _ in draft.period = .custom }
            .navigationTitle("Choose period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button("Apply period") { onApply(draft); dismiss() }
                    .buttonStyle(.appPrimary)
                    .disabled(draft.validation(calendar: calendar, now: Date()) != nil)
                    .accessibilityIdentifier("stats.applyPeriod")
                    .padding(AppSpacing.md)
                    .background(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceSecondary)
        }
    }
}
