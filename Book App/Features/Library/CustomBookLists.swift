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
    private let repository: LocalJSONRepository<[CustomBookList]>
    init(library: LibraryStore, repository: LocalJSONRepository<[CustomBookList]>? = nil) {
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
    @discardableResult func delete(ids: Set<UUID>) -> Bool { persist(lists.filter { !ids.contains($0.id) }) }
    func move(from offsets: IndexSet, to destination: Int) {
        var updated = lists; updated.move(fromOffsets: offsets, toOffset: destination); persist(updated)
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
    init(library: LibraryStore) { _model = State(initialValue: CustomListsViewModel(library: library)) }
    var body: some View {
        List {
            if model.lists.isEmpty {
                ContentUnavailableView("No Custom Lists", systemImage: "folder", description: Text("Create a collection and add books from your library."))
            }
            ForEach(model.lists) { list in
                NavigationLink {
                    CustomBookListDetailView(model: model, listID: list.id)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        let books = model.books(in: list)
                        if books.isEmpty { Image(systemName: "folder").foregroundStyle(Color.appAccent).frame(width: 54, height: 48) }
                        else {
                            HStack(spacing: 2) {
                                ForEach(Array(books.prefix(3))) { book in BookCoverView(url: book.coverURL).frame(width: 22, height: 36).clipped() }
                            }.accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(list.name).font(AppTypography.headline)
                            Text("\(books.count) books").font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                            if !list.description.isEmpty { Text(list.description).font(AppTypography.caption).foregroundStyle(Color.textSecondary).lineLimit(2) }
                        }
                    }
                }
            }
            .onDelete { offsets in pendingDelete = Set(offsets.map { model.lists[$0].id }) }
            .onMove { model.move(from: $0, to: $1) }
            if !model.canSave { Button("Retry Loading Lists") { model.reload() } }
        }
        .scrollContentBackground(.hidden).background(Color.surfaceSecondary)
        .navigationTitle("Custom Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("New List", systemImage: "plus") { isCreating = true }.disabled(!model.canSave) }
            ToolbarItem(placement: .topBarLeading) { EditButton().disabled(!model.canSave) }
        }
        .sheet(isPresented: $isCreating) { CustomBookListEditor(model: model, list: nil) }
        .alert("Delete List?", isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } })) {
            Button("Delete", role: .destructive) { model.delete(ids: pendingDelete); pendingDelete = [] }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: { Text("Only the collection will be deleted. Its books will stay in your library.") }
        .alert("Couldn’t Save Lists", isPresented: Binding(get: { !isCreating && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "Please try again.") }
    }
}

private struct CustomBookListEditor: View {
    @Environment(\.dismiss) private var dismiss
    let model: CustomListsViewModel
    let list: CustomBookList?
    @State private var name: String
    @State private var description: String
    @State private var selected: Set<String>
    init(model: CustomListsViewModel, list: CustomBookList?) {
        self.model = model; self.list = list
        _name = State(initialValue: list?.name ?? "")
        _description = State(initialValue: list?.description ?? "")
        _selected = State(initialValue: Set(list?.bookIDs ?? []))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                }
                Section("Books in Your Library") {
                    if model.library.books.isEmpty { Text("Add books using Search first.").foregroundStyle(Color.textSecondary) }
                    ForEach(model.library.books) { book in
                        Toggle(isOn: Binding(get: { selected.contains(book.id) }, set: { if $0 { selected.insert(book.id) } else { selected.remove(book.id) } })) {
                            HStack(spacing: AppSpacing.sm) {
                                BookCoverView(url: book.coverURL).frame(width: 30, height: 44).clipped().accessibilityHidden(true)
                                Text(book.title).font(AppTypography.body)
                            }
                        }.tint(Color.appAccent)
                    }
                }
            }.navigationTitle(list == nil ? "New List" : "Edit List").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let oldOrder = list?.bookIDs.filter { selected.contains($0) } ?? []
                            let members = oldOrder + model.library.books.map(\.id).filter { selected.contains($0) && !oldOrder.contains($0) }
                            if model.save(id: list?.id, name: name, description: description, bookIDs: members) { dismiss() }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.canSave)
                    }
                }
                .alert("Couldn’t Save List", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "Please try again.") }
        }
    }
}

private struct CustomBookListDetailView: View {
    let model: CustomListsViewModel
    let listID: UUID
    @State private var isEditing = false
    var body: some View {
        Group {
            if let list = model.list(id: listID) {
                List {
                    if !list.description.isEmpty { Text(list.description).font(AppTypography.body).foregroundStyle(Color.textSecondary) }
                    if model.books(in: list).isEmpty { ContentUnavailableView("This List Is Empty", systemImage: "books.vertical", description: Text("Use Edit List to add saved books.")) }
                    ForEach(model.books(in: list)) { book in
                        NavigationLink {
                            BookDetailView(book: book, onBookUpdated: { model.library.updateBook($0) }, onBookRemoved: { model.library.removeBook(id: $0) })
                        } label: { BookRowCard(book: book) }
                        .swipeActions { Button("Remove", role: .destructive) { model.remove(bookID: book.id, from: listID) } }
                    }
                }.scrollContentBackground(.hidden).background(Color.surfaceSecondary)
                    .navigationTitle(list.name)
                    .toolbar { Button("Edit List") { isEditing = true } }
                    .sheet(isPresented: $isEditing) { CustomBookListEditor(model: model, list: model.list(id: listID)) }
            } else { ContentUnavailableView("List Unavailable", systemImage: "folder") }
        }
        .alert("Couldn’t Save List", isPresented: Binding(get: { !isEditing && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "Please try again.") }
    }
}
