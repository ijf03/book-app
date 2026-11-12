import SwiftUI

struct SearchView: View {

    @State
    private var viewModel: SearchViewModel
    @State private var searchRequest = 0
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var discovery: BookDiscoveryViewModel

    let libraryStore: LibraryStore

    init(
        repository: any BookRepository,
        libraryStore: LibraryStore,
        initialSearch: AppRouter.SearchRequest? = nil
    ) {
        let search = SearchViewModel(repository: repository)
        let discoveryModel = BookDiscoveryViewModel(repository: repository)
        if let initialSearch {
            search.apply(initialSearch)
            discoveryModel.topic = search.selectedGenre
        }
        _viewModel = State(initialValue: search)
        _discovery = State(initialValue: discoveryModel)
        _searchRequest = State(initialValue: initialSearch == nil ? 0 : 1)
        self.libraryStore = libraryStore
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    let layout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
                        : AnyLayout(HStackLayout(spacing: AppSpacing.sm))
                    layout {
                    HStack {
                        Image(systemName: "magnifyingglass").accessibilityHidden(true)
                        TextField("Search title or author", text: $viewModel.searchText)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit { searchFocused = false; searchRequest += 1 }
                        if !viewModel.searchText.isEmpty {
                            Button { viewModel.searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    filterPicker
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
                .background(Color.surface)

                Divider()

                content
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
            .background(Color.surfaceSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Find Books")
            .onChange(of: discovery.topic) { _, genre in
                viewModel.selectedGenre = genre
                searchRequest += 1
            }
            .onChange(of: viewModel.selectedFilter) { _, _ in
                if !viewModel.searchText.isEmpty { searchRequest += 1 }
            }
            .onChange(of: viewModel.searchText) { _, text in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchRequest += 1
                    viewModel.selectedFilter = .all
                    if viewModel.selectedGenre == "All" { viewModel.clear() }
                }
            }
            .task(id: searchRequest) {
                guard searchRequest > 0 else { return }
                await viewModel.search()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {

        case .idle:
            idleState

        case .loading:
            loadingState

        case .loaded(let books):
            resultsView(books)

        case .failed(let message):
            errorState(message)
        }
    }

    // MARK: - Filters

    private var genreOptions: [String] {
        BookDiscoveryViewModel.topics.contains(discovery.topic)
            ? BookDiscoveryViewModel.topics : BookDiscoveryViewModel.topics + [discovery.topic]
    }

    private var filterPicker: some View {
        Menu {
            Picker("Search by", selection: $viewModel.selectedFilter) {
                ForEach(BookSearchFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            Picker("Genre", selection: $discovery.topic) {
                ForEach(genreOptions, id: \.self) { topic in
                    Text(topic).tag(topic)
                }
            }
        } label: {
            // Measure every option so changing genres never resizes the search field.
            ZStack(alignment: .leading) {
                ForEach(genreOptions, id: \.self) { topic in
                    Label(topic, systemImage: "line.3.horizontal.decrease")
                        .hidden()
                        .accessibilityHidden(true)
                }
                Label(discovery.topic, systemImage: "line.3.horizontal.decrease")
            }
            .font(AppTypography.caption)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: AppLayout.minimumTapTarget)
            .padding(.horizontal, AppSpacing.sm)
            .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Search filters")
        .accessibilityValue("\(viewModel.selectedFilter.displayName), \(discovery.topic)")
        .accessibilityIdentifier("search.discovery.genre")
    }

    // MARK: - Idle

    private var idleState: some View {
        BookDiscoveryView(model: discovery, library: libraryStore)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(
            spacing: AppSpacing.md
        ) {
            SwiftUI.ProgressView()

            Text("Searching books…")
                .font(AppTypography.body)
                .foregroundStyle(
                    Color.textSecondary
                )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(
        _ books: [BookSearchResult]
    ) -> some View {

        if books.isEmpty {
            ContentUnavailableView.search(
                text: viewModel.searchText
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(books) { book in

                        NavigationLink {
                            SearchBookDetailView(
                                book: book,
                                libraryStore:
                                    libraryStore
                            )
                        } label: {

                            SearchResultRow(
                                book: book,
                                isAdded:
                                    libraryStore.contains(
                                        bookID: book.id
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        SearchSynopsisDisclosure(book: book, scope: libraryStore.accountScope)

                        Divider()
                    }
                }
                .padding(
                    .horizontal,
                    AppSpacing.md
                )
            }
        }
    }

    // MARK: - Error

    private func errorState(
        _ message: String
    ) -> some View {

        ContentUnavailableView {
            Label(
                "Couldn't Search",
                systemImage:
                    "wifi.exclamationmark"
            )
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                searchRequest += 1
            }
            .buttonStyle(
                AppButtonStyle(
                    kind: .secondary
                )
            )
        }
    }
}
