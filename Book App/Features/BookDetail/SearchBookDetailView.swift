import SwiftUI

struct SearchBookDetailView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let libraryStore: LibraryStore
    @Environment(\.bookCatalogue) private var repository
    @State private var model: BookMetadataViewModel
    @State private var isShowingAddSheet = false
    @State private var isShowingEditions = false
    @State private var request = 0

    init(book: BookSearchResult, libraryStore: LibraryStore) {
        self.libraryStore = libraryStore
        _model = State(initialValue: BookMetadataViewModel(book: book))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.md))
                layout {
                    BookCoverView(url: model.result.coverURL).frame(width: AppLayout.homeCoverWidth)
                        .accessibilityLabel("Cover of \(model.result.title)")
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(model.result.title).font(AppTypography.title).fontDesign(.serif)
                            .accessibilityAddTraits(.isHeader)
                        Text(model.result.authorText).foregroundStyle(Color.textSecondary)
                    }
                }
                BookMetadataSection(book: model.result, isLoading: model.isLoading, error: model.error,
                                    retry: { request += 1 }, chooseEdition: { isShowingEditions = true })
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: AppLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Book details")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: AppSpacing.sm) {
                if libraryStore.contains(bookID: model.result.id) {
                    Label("Added to library", systemImage: "checkmark.circle.fill")
                        .frame(minHeight: AppLayout.minimumTapTarget)
                } else {
                    Button("Add to library") { isShowingAddSheet = true }
                        .buttonStyle(AppButtonStyle(kind: .primary))
                }
                if let error = libraryStore.persistenceError { Text(error).font(AppTypography.caption) }
            }.padding(AppSpacing.md).background(Color.surface)
        }
        .task(id: request) {
            guard let repository else { return }
            await model.load(using: repository, scope: libraryStore.accountScope)
        }
        .sheet(isPresented: $isShowingEditions) {
            BookEditionPicker(model: model, scope: libraryStore.accountScope, onSelect: { _ in })
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddBookSheet(book: model.result) { status, format in
                libraryStore.addBook(BookFactory.makeBook(from: model.result, status: status, format: format))
            }
        }
    }
}


#Preview("Search details") {
    NavigationStack {
        SearchBookDetailView(book: .init(id: "/works/OL1W", title: "A book to discover", authors: ["An author"],
            description: "Explore the synopsis before adding a book to your library. Publication information and edition selection sit below, while the Add to library action stays within reach.",
            coverURL: nil, pageCount: 320, genres: ["Fantasy", "Romance"]),
            libraryStore: LibraryStore(books: [], localDataSource: LocalLibraryDataSource()))
    }
}

#Preview("Search details · large text · dark") {
    NavigationStack {
        SearchBookDetailView(book: .init(id: "/works/OL1W", title: "A book to discover", authors: ["An author"],
            description: "A synopsis that remains readable at larger text sizes.", coverURL: nil, pageCount: nil,
            genres: ["Science fiction", "Mystery"]),
            libraryStore: LibraryStore(books: [], localDataSource: LocalLibraryDataSource()))
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
