import SwiftUI

struct StatisticsPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @State private var draft: StatisticsSelection
    let years: [Int]
    let onApply: (StatisticsSelection) -> Void

    init(selection: StatisticsSelection, years: [Int] = [], onApply: @escaping (StatisticsSelection) -> Void) {
        _draft = State(initialValue: selection)
        self.years = years
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(StatisticsPeriod.allCases) { period in
                        Button { draft.period = period } label: {
                            HStack {
                                Text(period.title).foregroundStyle(Color.textPrimary)
                                Spacer()
                                if draft.period == period {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: AppLayout.minimumTapTarget)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(draft.period == period ? .isSelected : [])
                    }
                } header: {
                    Text("Presets")
                } footer: {
                    Text("Choose a preset, a calendar year, or Custom dates for a date range.")
                }
                .accessibilityIdentifier("stats.periodOptions")
                if !years.isEmpty {
                    Section("Calendar year") {
                        Menu {
                            ForEach(years, id: \.self) { year in
                                Button(String(year)) { selectYear(year) }
                            }
                        } label: {
                            Label("Choose a year", systemImage: "calendar")
                        }
                    }
                }
                if draft.period == .custom {
                    Section("From") {
                        DatePicker("From", selection: $draft.from, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .accessibilityIdentifier("stats.from")
                    }
                    Section("To") {
                        DatePicker("To", selection: $draft.to, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .accessibilityIdentifier("stats.to")
                    }
                    if let message = draft.validation(calendar: calendar, now: Date()) {
                        Section {
                            Text(message).foregroundStyle(Color.danger)
                                .accessibilityIdentifier("stats.dateError")
                        }
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
    private func selectYear(_ year: Int) {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let next = calendar.date(byAdding: .year, value: 1, to: start),
              let last = calendar.date(byAdding: .day, value: -1, to: next) else { return }
        draft = StatisticsSelection(period: .custom, from: start, to: min(last, Date()))
    }

}


#Preview("Statistics period picker") {
    StatisticsPeriodSheet(selection: .init(period: .year, from: .now, to: .now),
                          years: [2026, 2025, 2024]) { _ in }
}
