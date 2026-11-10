import SwiftUI

struct SearchView: View {

    @State
    private var viewModel: SearchViewModel
    @State private var discovery: BookDiscoveryViewModel

    let libraryStore: LibraryStore

    init(
        repository: any BookRepository,
        libraryStore: LibraryStore
    ) {
        _viewModel = State(
            initialValue: SearchViewModel(
                repository: repository
            )
        )
        
        _discovery = State(initialValue: BookDiscoveryViewModel(repository: repository))
        self.libraryStore = libraryStore
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                filterPicker

                Divider()

                content
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("Find Books")
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search title or author"
            )
            .task(id: searchTaskID) {
                await performDebouncedSearch()
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

    // MARK: - Search Trigger

    private var searchTaskID: String {
        "\(viewModel.searchText)-\(viewModel.selectedFilter.rawValue)"
    }

    private func performDebouncedSearch() async {

        let query = viewModel.searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            await viewModel.search()
            return
        }

        do {
            try await Task.sleep(
                for: .milliseconds(500)
            )

            try Task.checkCancellation()

            await viewModel.search()

        } catch is CancellationError {
            return

        } catch {
            return
        }
    }

    // MARK: - Filters

    private var filterPicker: some View {
        Picker(
            "Search Filter",
            selection: $viewModel.selectedFilter
        ) {
            ForEach(
                BookSearchFilter.allCases
            ) { filter in
                Text(filter.displayName)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.surface)
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
                Task {
                    await viewModel.search()
                }
            }
            .buttonStyle(
                AppButtonStyle(
                    kind: .secondary
                )
            )
        }
    }
}
