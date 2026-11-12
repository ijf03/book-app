import SwiftUI

struct DiscoveryRecommendationsSection: View {
    let title: LocalizedStringResource
    let recommendations: [BookDiscoveryViewModel.Recommendation]
    let library: LibraryStore
    var loadsOnDemand = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(recommendations) { recommendation in
                DiscoverySynopsisCard(recommendation: recommendation, library: library, loadsOnDemand: loadsOnDemand)
            }
        }
    }
}

private struct DiscoverySynopsisCard: View {
    let recommendation: BookDiscoveryViewModel.Recommendation
    let library: LibraryStore
    var loadsOnDemand = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label(recommendation.reason, systemImage: "sparkles")
                .font(AppTypography.caption)
                .foregroundStyle(Color.appAccent)

            Text(recommendation.book.title)
                .font(AppTypography.title)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(recommendation.book.authorText)
                .font(AppTypography.body)
                .foregroundStyle(Color.textSecondary)
            if !recommendation.book.genreChips.isEmpty {
                Text(recommendation.book.genreChips.formatted())
                    .font(AppTypography.caption)
                    .foregroundStyle(Color.appAccent)
            }

            if loadsOnDemand {
                SearchSynopsisDisclosure(book: recommendation.book, scope: library.accountScope)
            } else if let synopsis = recommendation.book.description,
               !synopsis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(synopsis)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                Text("No synopsis available from Open Library.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.textSecondary)
            }

            NavigationLink {
                SearchBookDetailView(book: recommendation.book, libraryStore: library)
            } label: {
                Label("View book details", systemImage: "arrow.right")
            }
            .buttonStyle(AppButtonStyle(kind: .secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
