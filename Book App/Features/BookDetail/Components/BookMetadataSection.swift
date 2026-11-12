import SwiftUI

private struct BookCatalogueKey: EnvironmentKey {
    static let defaultValue: (any BookRepository)? = nil
}
extension EnvironmentValues {
    var bookCatalogue: (any BookRepository)? {
        get { self[BookCatalogueKey.self] }
        set { self[BookCatalogueKey.self] = newValue }
    }
}

struct BookMetadataSection: View {
    @Environment(AppRouter.self) private var router: AppRouter?
    let book: BookSearchResult
    let isLoading: Bool
    let error: String?
    let retry: () -> Void
    let chooseEdition: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Synopsis").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                    if let description = book.description, !description.isEmpty {
                        Text(description).font(AppTypography.body).textSelection(.enabled)
                    } else if !isLoading && error == nil {
                        Text("Open Library has no synopsis available for this book yet.")
                            .foregroundStyle(Color.textSecondary)
                    }
                    if isLoading { SwiftUI.ProgressView("Loading book information…") }
                    if let error {
                        Text(error).font(AppTypography.caption)
                        Button("Retry", action: retry).frame(minHeight: AppLayout.minimumTapTarget)
                    }
                }
            }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Publication & edition").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                    if let first = book.metadata?.firstPublished { LabeledContent("First published", value: first) }
                    if let edition = book.metadata?.edition {
                        LabeledContent("Edition", value: edition.title)
                        if let date = edition.published { LabeledContent("Published", value: date) }
                        if !edition.publishers.isEmpty { LabeledContent("Publisher", value: edition.publishers.formatted()) }
                        if !edition.languages.isEmpty { LabeledContent("Language", value: edition.languages.formatted()) }
                        if let pages = edition.pages { LabeledContent("Pages", value: pages.formatted()) }
                        if let format = edition.physicalFormat { LabeledContent("Catalogue format", value: format) }
                        if !edition.isbn.isEmpty { LabeledContent("ISBN", value: edition.isbn.formatted()).textSelection(.enabled) }
                    } else {
                        Text("Choose your edition for its language, publisher, ISBN, format and page count.")
                            .foregroundStyle(Color.textSecondary)
                        if let pages = book.pageCount { Text("Catalogue estimate: \(pages) pages. Editions may differ.").font(AppTypography.caption) }
                    }
                    Button("Choose edition", action: chooseEdition)
                        .frame(minHeight: AppLayout.minimumTapTarget)
                        .disabled(book.metadata == nil)
                    Text("Missing catalogue fields are omitted. Your reading format is tracked separately.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Discover more").font(AppTypography.headline).accessibilityAddTraits(.isHeader)
                    if let rating = book.metadata?.communityRating {
                        Label("Open Library rating: \(rating.formatted(.number.precision(.fractionLength(1)))) / 5", systemImage: "star")
                        if let count = book.metadata?.communityRatingCount { Text("\(count) community ratings").font(AppTypography.caption) }
                    } else { Text("No community rating available.").foregroundStyle(Color.textSecondary) }
                    Text("Community ratings are separate from your review.").font(AppTypography.caption)
                    if let url = book.metadata?.edition?.sourceURL ?? book.metadata?.sourceURL {
                        Link("View on Open Library / check reading availability", destination: url)
                            .frame(minHeight: AppLayout.minimumTapTarget)
                    }
                    ForEach(book.authors, id: \.self) { author in
                        Button("More by \(author)") { router?.explore(author: author) }
                            .frame(minHeight: AppLayout.minimumTapTarget)
                            .accessibilityHint("Searches for this author in the app.")
                    }
                    ForEach(book.genreChips, id: \.self) { genre in
                        Button("Explore \(genre)") { router?.explore(genre: genre) }
                            .frame(minHeight: AppLayout.minimumTapTarget)
                            .accessibilityHint("Searches for this genre in the app.")
                    }
                    Text("Author and genre searches open Find Books. The Open Library availability link opens its website.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

struct GenreChips: View {
    let genres: [String]
    @ScaledMetric private var minimumWidth = AppLayout.genreChipMinimumWidth
    var body: some View {
        if genres.isEmpty {
            Text("Genre not recorded").font(AppTypography.caption).foregroundStyle(Color.textSecondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth))], alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre).font(AppTypography.caption)
                        .padding(AppSpacing.sm).frame(maxWidth: .infinity)
                        .background(Color.accentTint, in: Capsule())
                        .accessibilityLabel("Genre: \(genre)")
                }
            }
        }
    }
}

struct BookEditionPicker: View {
    @Bindable var model: BookMetadataViewModel
    let scope: AccountStorageScope?
    let onSelect: (BookEdition) -> Void
    @Environment(\.bookCatalogue) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var request = 0
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select the edition you read. This updates catalogue details, language, cover and page count, but preserves recorded progress and sessions.")
                }
                ForEach(model.editions) { edition in
                    Button {
                        model.select(edition)
                        onSelect(edition)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(edition.title).font(AppTypography.headline)
                            Text([edition.published, edition.publishers.first, edition.languages.first, edition.physicalFormat].compactMap { $0 }.joined(separator: " · "))
                                .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                            if let pages = edition.pages { Text("\(pages) pages").font(AppTypography.caption) }
                            if let isbn = edition.isbn.first { Text("ISBN: \(isbn)").font(AppTypography.caption) }
                        }
                    }.frame(minHeight: AppLayout.minimumTapTarget)
                }
                if model.isLoadingEditions { SwiftUI.ProgressView("Loading editions…") }
                if let error = model.editionError { Text(error) }
                if model.hasMoreEditions {
                    Button(model.editionError == nil ? "Load more editions" : "Retry") { request += 1 }
                        .disabled(model.isLoadingEditions)
                } else if model.editions.isEmpty { Text("No editions available.") }
            }
            .navigationTitle("Choose edition")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: request) {
                guard let repository else { return }
                await model.loadEditions(using: repository, scope: scope)
            }
        }
    }
}
