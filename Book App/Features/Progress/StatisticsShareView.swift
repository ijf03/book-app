import SwiftUI
import Observation
import CoreTransferable
import UniformTypeIdentifiers

struct StatisticsShareImage: Transferable {
    let png: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName("Reading-insights.png")
    }
}

@MainActor @Observable
final class StatisticsShareModel {
    private(set) var image: Image?
    private(set) var export: StatisticsShareImage?
    private(set) var failed = false

    func render(_ statistics: ReadingStatistics) {
        let renderer = ImageRenderer(content: StatisticsShareCard(statistics: statistics)
            .frame(width: AppLayout.statisticsExportWidth)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large))
        renderer.scale = AppLayout.statisticsExportScale
        guard let bitmap = renderer.uiImage, let png = bitmap.pngData() else {
            failed = true
            return
        }
        image = Image(uiImage: bitmap)
        export = StatisticsShareImage(png: png)
        failed = false
    }
}

struct StatisticsShareView: View {
    let statistics: ReadingStatistics
    @State private var model = StatisticsShareModel()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Preview your statistics image before sharing. It includes the dates, recorded totals and your highest-rated completed books. Your account details, notes and review text are excluded.")
                        .font(AppTypography.body)
                    if let image = model.image, let export = model.export {
                        image.resizable().scaledToFit()
                            .accessibilityLabel("Reading statistics image preview")
                        ShareLink(item: export, preview: SharePreview("My reading insights", image: image)) {
                            Label("Share image", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(AppButtonStyle(kind: .primary))
                    } else if model.failed {
                        Text("The image couldn’t be created.")
                        Button("Retry") { model.render(statistics) }
                    } else { SwiftUI.ProgressView("Preparing image…") }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: AppLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("Share reading insights")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { model.render(statistics) }
        }
    }
}

struct StatisticsShareCard: View {
    let statistics: ReadingStatistics
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Label("BOOK TRACKER", systemImage: "book.closed.fill")
                .font(AppTypography.headline).foregroundStyle(Color.appAccent)
            Text("My reading insights").font(AppTypography.largeTitle)
            if let interval = statistics.interval {
                Text("\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(interval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTypography.body).foregroundStyle(Color.textSecondary)
            }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("\(statistics.completedBooks) books completed").font(AppTypography.title)
                    Text("\(statistics.pages) recorded pages").font(AppTypography.title)
                    Text("\(Duration.seconds(statistics.seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))) recorded reading").font(AppTypography.title)
                    if let rating = statistics.averageRating {
                        Text("\(rating.formatted(.number.precision(.fractionLength(1)))) / 5 average rating").font(AppTypography.title)
                    }
                }
            }
            Text("My top rated finishes").font(AppTypography.title)
            if statistics.extended.topBooks.isEmpty {
                Text("No rated, dated completions in this period.").font(AppTypography.body)
            }
            ForEach(statistics.extended.topBooks) { book in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(book.title).font(AppTypography.headline).fixedSize(horizontal: false, vertical: true)
                    Text("\(book.rating ?? 0) / 5").font(AppTypography.body).foregroundStyle(Color.appAccent)
                }
            }
            Text("Time excludes pauses and unfinished sessions. Pages count recorded new coverage. Average rating uses review creation dates; top books use completion dates and current ratings.")
                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary)
    }
}

#Preview("Share card") {
    StatisticsShareCard(statistics: ReadingStatistics())
}
