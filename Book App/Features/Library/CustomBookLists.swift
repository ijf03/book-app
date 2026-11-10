import Foundation
import Observation
import SwiftUI

struct CustomBookList: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var description: String
    var bookIDs: [String]
}

@MainActor @Observable final class CustomListsViewModel {
    private(set) var lists: [CustomBookList] = []
    var errorMessage: String?
    private(set) var canSave = true
    let library: LibraryStore
    let searchRepository: any BookRepository
    private let repository: LocalJSONRepository<[CustomBookList]>
    init(library: LibraryStore, repository: LocalJSONRepository<[CustomBookList]>? = nil, searchRepository: any BookRepository = DefaultBookRepository(remoteDataSource: OpenLibraryRemoteDataSource())) {
        self.searchRepository = searchRepository
        self.library = library; self.repository = repository ?? .init(fileName: "custom-book-lists.json", scope: library.accountScope); reload()
    }
    func reload() {
        do { lists = try repository.load(default: []); canSave = true; errorMessage = nil }
        catch { canSave = false; errorMessage = "Your lists couldn’t be loaded. The saved file has been preserved." }
    }
    func list(id: UUID) -> CustomBookList? { lists.first { $0.id == id } }
    func books(in list: CustomBookList) -> [Book] { list.bookIDs.compactMap { library.book(id: $0) } }
    @discardableResult private func persist(_ updated: [CustomBookList]) -> Bool {
        guard canSave else { errorMessage = "Reload your saved lists before making changes."; return false }
        do { try repository.save(updated); lists = updated; errorMessage = nil; return true }
        catch { errorMessage = "Your changes couldn’t be saved. Your previous lists are unchanged."; return false }
    }
    @discardableResult func save(id: UUID?, name: String, description: String, bookIDs: [String]) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { errorMessage = "Enter a list name."; return false }
        var seen = Set<String>()
        let members = bookIDs.filter { library.book(id: $0) != nil && seen.insert($0).inserted }
        let value = CustomBookList(id: id ?? UUID(), name: name, description: description.trimmingCharacters(in: .whitespacesAndNewlines), bookIDs: members)
        var updated = lists
        if let id {
            guard let index = updated.firstIndex(where: { $0.id == id }) else { errorMessage = "This list no longer exists."; return false }
            updated[index] = value
        } else { updated.append(value) }
        return persist(updated)
    }
    func book(for result: BookSearchResult) -> Book {
        library.books.first { $0.id == result.id || $0.sourceBookID == result.id }
            ?? BookFactory.makeBook(from: result, status: .toRead, format: .physical)
    }

    @discardableResult func saveSelection(id: UUID?, name: String, description: String, books: [Book]) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "Enter a list name."); return false
        }
        reload()
        guard canSave, library.accountScope?.isActive != false else { return false }
        if let id, list(id: id) == nil {
            errorMessage = String(localized: "This list no longer exists."); return false
        }
        var ids: [String] = []
        for draft in books {
            if let existing = library.books.first(where: { $0.id == draft.id || $0.sourceBookID == draft.id }) {
                ids.append(existing.id)
            } else {
                guard library.addBook(draft) else {
                    errorMessage = String(localized: "Some books couldn’t be saved. Your selections are still here. Please retry."); return false
                }
                ids.append(draft.id)
            }
        }
        guard save(id: id, name: name, description: description, bookIDs: ids) else {
            errorMessage = String(localized: "Your books were saved, but the list couldn’t be saved. Please retry."); return false
        }
        return true
    }

    @discardableResult func delete(ids: Set<UUID>) -> Bool { persist(lists.filter { !ids.contains($0.id) }) }
    func move(from offsets: IndexSet, to destination: Int) {
        var updated = lists; updated.move(fromOffsets: offsets, toOffset: destination); persist(updated)
    }
    func moveBooks(in id: UUID, from offsets: IndexSet, to destination: Int) {
        guard let list = list(id: id) else { return }
        var visibleIDs = books(in: list).map(\.id)
        guard offsets.allSatisfy({ visibleIDs.indices.contains($0) }),
              (0...visibleIDs.count).contains(destination) else { return }
        visibleIDs.move(fromOffsets: offsets, toOffset: destination)
        // Keep temporarily unavailable members in place while reordering visible books.
        let visibleSet = Set(visibleIDs)
        var iterator = visibleIDs.makeIterator()
        var updated = lists
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].bookIDs = list.bookIDs.map { visibleSet.contains($0) ? (iterator.next() ?? $0) : $0 }
        persist(updated)
    }

    func remove(bookID: String, from id: UUID) {
        guard let list = list(id: id) else { return }
        save(id: id, name: list.name, description: list.description, bookIDs: list.bookIDs.filter { $0 != bookID })
    }
}

struct CustomBookListsView: View {
    @State private var model: CustomListsViewModel
    @State private var isCreating = false
    @State private var pendingDelete = Set<UUID>()
    private let isEmbedded: Bool
    private let onSelectShelf: ((ReadingStatus?) -> Void)?

    init(library: LibraryStore, isEmbedded: Bool = false,
         repository: any BookRepository = DefaultBookRepository(remoteDataSource: OpenLibraryRemoteDataSource()),
         onSelectShelf: ((ReadingStatus?) -> Void)? = nil) {
        self.isEmbedded = isEmbedded
        self.onSelectShelf = onSelectShelf
        _model = State(initialValue: CustomListsViewModel(library: library, searchRepository: repository))
    }

    var body: some View {
        List {
            if let onSelectShelf {
                Section {
                    shelf("All", symbol: "books.vertical", count: model.library.books.count) { onSelectShelf(nil) }
                    shelf("To Read", symbol: "bookmark", count: model.library.books.filter { $0.status == .toRead }.count) { onSelectShelf(.toRead) }
                    shelf("Reading", symbol: "book", count: model.library.books.filter { $0.status == .reading }.count) { onSelectShelf(.reading) }
                    shelf("Completed", symbol: "checkmark.circle", count: model.library.books.filter { $0.status == .completed }.count) { onSelectShelf(.completed) }
                }
            }
            Section {
                if model.lists.isEmpty {
                    Text("Tap + to create a list and search for books to add.")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.vertical, AppSpacing.sm)
                }
                ForEach(model.lists) { list in
                    NavigationLink {
                        CustomBookListDetailView(model: model, listID: list.id)
                    } label: {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "folder")
                                .font(AppTypography.title)
                                .foregroundStyle(Color.appAccent)
                                .frame(width: AppLayout.minimumTapTarget, height: AppLayout.minimumTapTarget)
                                .background(Color.accentTint, in: RoundedRectangle(cornerRadius: AppRadius.md))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(list.name).font(AppTypography.headline)
                                if !list.description.isEmpty {
                                    Text(list.description).font(AppTypography.caption)
                                        .foregroundStyle(Color.textSecondary).lineLimit(2)
                                }
                            }
                            Spacer()
                            Text(model.books(in: list).count.formatted())
                                .font(AppTypography.body).foregroundStyle(Color.textSecondary)
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                }
                .onDelete { offsets in pendingDelete = Set(offsets.map { model.lists[$0].id }) }
                .onMove { model.move(from: $0, to: $1) }
                if !model.canSave { Button("Retry Loading Lists") { model.reload() } }
            } header: {
                HStack {
                    Text("My Lists").font(AppTypography.title).foregroundStyle(Color.textPrimary)
                    Spacer()
                    Button { isCreating = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.title)
                            .frame(minWidth: AppLayout.minimumTapTarget, minHeight: AppLayout.minimumTapTarget)
                    }
                    .disabled(!model.canSave)
                    .accessibilityLabel("Create a list")
                    .accessibilityIdentifier("library.createList")
                }
                .textCase(nil)
            }
        }
        .onChange(of: model.library.accountScope?.cloudRevision) { _, _ in model.reload() }
        .scrollContentBackground(.hidden).background(Color.surfaceSecondary)
        .navigationTitle(isEmbedded ? "My Library" : "My Lists")
        .onAppear { model.reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton().disabled(!model.canSave || model.lists.isEmpty)
            }
        }
        .sheet(isPresented: $isCreating) { CustomBookListEditor(model: model, list: nil) }
        .alert("Delete List?", isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })) {
            Button("Delete", role: .destructive) { model.delete(ids: pendingDelete); pendingDelete = [] }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: { Text("Only the collection will be deleted. Its books will stay in your library.") }
        .alert("Couldn’t Save Lists", isPresented: Binding(get: { !isCreating && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "Please try again.") }
    }

    private func shelf(_ title: LocalizedStringResource, symbol: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: symbol)
                    .font(AppTypography.title)
                    .foregroundStyle(Color.appAccent)
                    .frame(width: AppLayout.minimumTapTarget, height: AppLayout.minimumTapTarget)
                    .background(Color.accentTint, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .accessibilityHidden(true)
                Text(title).font(AppTypography.headline).foregroundStyle(Color.textPrimary)
                Spacer()
                Text(count.formatted()).foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right").font(AppTypography.caption)
                    .foregroundStyle(Color.textSecondary).accessibilityHidden(true)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomBookListEditor: View {
    @Environment(\.dismiss) private var dismiss
    let model: CustomListsViewModel
    let list: CustomBookList?
    @State private var name: String
    @State private var description: String
    @State private var selected: [Book]
    @State private var search: SearchViewModel
    @State private var retry = 0

    init(model: CustomListsViewModel, list: CustomBookList?) {
        self.model = model
        self.list = list
        _name = State(initialValue: list?.name ?? "")
        _description = State(initialValue: list?.description ?? "")
        _selected = State(initialValue: list.map { model.books(in: $0) } ?? [])
        _search = State(initialValue: SearchViewModel(repository: model.searchRepository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                }
                Section("Selected books · \(selected.count)") {
                    if selected.isEmpty { Text("Search below and select books for this list.").foregroundStyle(Color.textSecondary) }
                    ForEach(selected) { book in
                        HStack(spacing: AppSpacing.sm) {
                            Text(book.title)
                            Spacer()
                            Button {
                                selected.removeAll { $0.id == book.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .frame(minWidth: AppLayout.minimumTapTarget, minHeight: AppLayout.minimumTapTarget)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(book.title) from selection")
                        }
                    }
                }
                Section {
                    Text("New selections are saved to your library as To Read when you save this list. Existing books keep their status and progress.")
                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                }
                Section("Find books") {
                    TextField("Search title or author", text: $search.searchText)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .accessibilityIdentifier("list.bookSearch")
                    Picker("Search by", selection: $search.selectedFilter) {
                        ForEach(BookSearchFilter.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                    searchResults
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(list == nil ? "New List" : "Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(search.searchText)-\(search.selectedFilter.rawValue)-\(retry)") {
                do {
                    if !search.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        try await Task.sleep(for: .milliseconds(350))
                    }
                    try Task.checkCancellation()
                    await search.search()
                } catch { }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.saveSelection(id: list?.id, name: name, description: description, books: selected) { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.canSave)
                }
            }
            .alert("Couldn’t Save List", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(model.errorMessage ?? "Please try again.") }
        }
    }

    @ViewBuilder private var searchResults: some View {
        switch search.state {
        case .idle:
            Label("Search the book catalogue, not just your library.", systemImage: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)
        case .loading:
            SwiftUI.ProgressView("Searching books…")
        case .failed(let message):
            Text(message).foregroundStyle(Color.textSecondary)
            Button("Retry search") { retry += 1 }
        case .loaded(let results):
            if results.isEmpty { Text("No books found. Try a different title or author.") }
            ForEach(results) { result in
                let book = model.book(for: result)
                let isSelected = selected.contains { $0.id == book.id }
                Button {
                    if isSelected { selected.removeAll { $0.id == book.id } }
                    else { selected.append(book) }
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        BookCoverView(url: result.coverURL)
                            .frame(width: AppLayout.insightCoverWidth, height: AppLayout.insightCoverWidth * 1.5)
                            .clipped().accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(result.title).font(AppTypography.headline).foregroundStyle(Color.textPrimary)
                            Text(result.authorText).font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(isSelected ? String(localized: "Remove") : String(localized: "Select")) \(result.title), \(result.authorText)")
            }
        }
    }
}

private struct CustomBookListDetailView: View {
    let model: CustomListsViewModel
    let listID: UUID
    @State private var isEditing = false
    @State private var editMode: EditMode = .inactive
    var body: some View {
        Group {
            if let list = model.list(id: listID) {
                List {
                    if !list.description.isEmpty { Text(list.description).font(AppTypography.body).foregroundStyle(Color.textSecondary) }
                    if model.books(in: list).isEmpty { ContentUnavailableView("This List Is Empty", systemImage: "books.vertical", description: Text("Use Edit List to search for books.")) }
                    ForEach(model.books(in: list)) { book in
                        NavigationLink {
                            BookDetailView(book: book, onBookUpdated: { model.library.updateBook($0) }, onBookRemoved: { model.library.removeBook(id: $0) })
                        } label: { BookRowCard(book: book) }
                        .swipeActions { Button("Remove", role: .destructive) { model.remove(bookID: book.id, from: listID) } }
                    }
                    .onMove { model.moveBooks(in: listID, from: $0, to: $1) }
                    .moveDisabled(!model.canSave)
                }
                    .environment(\.editMode, $editMode)
                    .scrollContentBackground(.hidden).background(Color.surfaceSecondary)
                    .navigationTitle(list.name)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(editMode.isEditing ? "Done" : "Reorder") {
                                editMode = editMode.isEditing ? .inactive : .active
                            }
                            .disabled(!model.canSave || model.books(in: list).count < 2)
                            .accessibilityHint("Drag the handles beside books to change their order.")
                            .accessibilityIdentifier("list.reorderBooks")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit List") { isEditing = true }
                                .disabled(editMode.isEditing)
                        }
                    }
                    .sheet(isPresented: $isEditing) { CustomBookListEditor(model: model, list: model.list(id: listID)) }
            } else { ContentUnavailableView("List Unavailable", systemImage: "folder") }
        }
        .alert("Couldn’t Save List", isPresented: Binding(get: { !isEditing && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "Please try again.") }
    }
}
