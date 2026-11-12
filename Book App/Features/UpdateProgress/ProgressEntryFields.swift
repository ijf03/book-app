import SwiftUI

struct ProgressEntryFields: View {
    @Bindable var model: UpdateProgressViewModel

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Picker("Reading format", selection: $model.format) {
                    ForEach(ReadingFormat.allCases) { Text($0.displayName).tag($0) }
                }
                if model.format == .immersive {
                    Picker("Read alongside audio", selection: $model.immersiveCompanion) {
                        Text("Physical book").tag(ReadingFormat.physical)
                        Text("Ebook").tag(ReadingFormat.ebook)
                    }
                }
                if model.format != .audiobook {
                    if model.format == .immersive {
                        Text("Reading position").font(AppTypography.headline)
                    }
                    if model.offersEbookUnits {
                        Picker("Ebook progress", selection: Binding(
                            get: { model.unit }, set: { model.changeUnit($0) }
                        )) {
                            Text("Percentage").tag(UpdateProgressViewModel.Unit.percentage)
                            Text("Pages").tag(UpdateProgressViewModel.Unit.page)
                        }
                        .pickerStyle(.menu)
                    }
                    if model.usesPages {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Total pages").font(AppTypography.caption)
                            TextField("Total pages", text: $model.pageCountText).keyboardType(.numberPad)
                            Text("Current page").font(AppTypography.caption)
                            TextField("Current page", text: $model.pageText).keyboardType(.numberPad)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Percentage read").font(AppTypography.caption)
                            TextField("Percentage, 0–100", text: $model.percentageText).keyboardType(.decimalPad)
                        }
                    }
                }
                if model.usesAudio {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        if model.format == .immersive {
                            Text("Audio position").font(AppTypography.headline)
                        }
                        Text("Total audiobook duration").font(AppTypography.caption)
                        TextField("Total duration, HH:MM:SS", text: $model.audioDurationText)
                            .keyboardType(.numbersAndPunctuation)
                        Text("Current audio position").font(AppTypography.caption)
                        TextField("Position, HH:MM:SS", text: $model.timestampText)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                Text("Totals are saved with this book and filled in next time. You can edit them if you change editions.")
                    .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                if model.format == .immersive {
                    Text("Both positions are saved. Shared progress uses whichever is furthest through the book, without counting it twice.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
                if let equivalents = model.equivalents {
                    Text(equivalents).font(AppTypography.caption)
                    Text("These are approximate positions. Chapters, editions and abridged audiobooks can differ.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
    }
}
