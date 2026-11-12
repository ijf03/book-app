import SwiftUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: BookSearchResult
    let existingBook: Book?
    @State private var model: CustomListsViewModel
    @State private var selectedStatus: ReadingStatus = .toRead
    @State private var selectedFormat: ReadingFormat = .physical
    @State private var selectedLists: Set<UUID> = []
    @State private var newListName = ""
    @State private var draftListName = ""
    @State private var isShowingNewList = false
    @State private var listSearch = ""
    @State private var isShowingSaveError = false

    init(book: BookSearchResult, library: LibraryStore, existingBook: Book? = nil) {
        self.book = book
        self.existingBook = existingBook
        _model = State(initialValue: CustomListsViewModel(library: library))
    }

    private func alreadyContainsBook(_ list: CustomBookList) -> Bool {
        existingBook.map { list.bookIDs.contains($0.id) } ?? false
    }

    private func isChecked(_ list: CustomBookList) -> Bool {
        alreadyContainsBook(list) || selectedLists.contains(list.id)
    }

    private var visibleLists: [CustomBookList] {
        let query = listSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = model.lists.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
        // Preserve the saved order within each group and stable list identities when selecting.
        return matches.filter { isChecked($0) } + matches.filter { !isChecked($0) }
    }

    private var newListToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                draftListName = newListName
                isShowingNewList = true
            } label: {
                Text("+ New")
            }
            .buttonStyle(AppCompactPillButtonStyle())
            .disabled(!model.canSave)
            .accessibilityLabel("Create a new list")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if existingBook == nil {
                    Section("Reading Status") {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(ReadingStatus.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                    Section("Reading Format") {
                        Picker("Format", selection: $selectedFormat) {
                            ForEach(ReadingFormat.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                }
                Section {
                    TextField("Search lists", text: $listSearch)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .accessibilityLabel("Search lists by name")
                    if !newListName.isEmpty {
                        Button {
                            draftListName = newListName
                            isShowingNewList = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(newListName).foregroundStyle(Color.textPrimary)
                                    Text("New list · created when you save")
                                        .font(AppTypography.caption).foregroundStyle(Color.textSecondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark.square.fill").foregroundStyle(Color.appAccent)
                            }
                            .frame(minHeight: AppLayout.minimumTapTarget)
                        }
                        .accessibilityHint("Edits the new list name.")
                    }
                    ForEach(visibleLists) { list in
                        let alreadyAdded = alreadyContainsBook(list)
                        let checked = isChecked(list)
                        Button {
                            if selectedLists.contains(list.id) { selectedLists.remove(list.id) }
                            else { selectedLists.insert(list.id) }
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: checked ? "checkmark.square.fill" : "square")
                                    .font(AppTypography.title)
                                    .foregroundStyle(Color.appAccent)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    Text(list.name).foregroundStyle(Color.textPrimary)
                                    if alreadyAdded {
                                        Text("Already in list")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: AppLayout.minimumTapTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded)
                        .accessibilityLabel(list.name)
                        .accessibilityValue(alreadyAdded ? "Already in list" : (checked ? "Checked" : "Unchecked"))
                        .accessibilityAddTraits(checked ? .isSelected : [])
                    }
                    if visibleLists.isEmpty {
                        Text(model.lists.isEmpty ? "No custom lists yet. Tap + New to create one." : "No matching lists.")
                            .foregroundStyle(Color.textSecondary)
                    }
                } header: {
                    Text("Custom lists")
                } footer: {
                    Text("Checked lists appear first. Lists the book already belongs to stay checked.")
                }
                if !model.canSave {
                    Section { Button("Retry Loading Lists") { model.reload() } }
                }
            }
            .navigationTitle(existingBook == nil ? "Add to Library" : "Add to Lists")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Couldn’t Save", isPresented: $isShowingSaveError) {
                Button("OK", role: .cancel) {}
            } message: { Text(model.errorMessage ?? "Your selections are still here. Please try again.") }
            .alert("New List", isPresented: $isShowingNewList) {
                TextField("List name", text: $draftListName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    newListName = draftListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    listSearch = ""
                }
                .disabled(draftListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("The list and this book’s membership will be saved when you tap Save or Add to Library.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if #available(iOS 26.0, *) {
                    newListToolbarItem.sharedBackgroundVisibility(.hidden)
                } else {
                    newListToolbarItem
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(existingBook == nil ? "Add to Library" : "Save") {
                    let draft = existingBook ?? BookFactory.makeBook(from: book, status: selectedStatus, format: selectedFormat)
                    if model.add(draft, to: selectedLists, newListName: newListName) { dismiss() }
                    else { isShowingSaveError = true }
                }
                .disabled(!model.canSave)
                .buttonStyle(AppButtonStyle(kind: .primary))
                .padding(AppSpacing.md)
                .background(Color.surface)
            }
        }
    }
}
