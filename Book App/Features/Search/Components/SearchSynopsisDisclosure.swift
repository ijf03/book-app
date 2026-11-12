import SwiftUI

/// Fetch on expansion, rather than issuing a detail request for every search result.
struct SearchSynopsisDisclosure: View {
    let scope: AccountStorageScope?
    @Environment(\.bookCatalogue) private var repository
    @State private var model: BookMetadataViewModel
    @State private var expanded = false
    @State private var request = 0
    @State private var loaded = false

    init(book: BookSearchResult, scope: AccountStorageScope?) {
        self.scope = scope
        _model = State(initialValue: BookMetadataViewModel(book: book))
    }

    var body: some View {
        DisclosureGroup("Read synopsis", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let text = model.result.description, !text.isEmpty {
                    Text(text).font(AppTypography.body).foregroundStyle(Color.textPrimary)
                } else if loaded && model.error == nil {
                    Text("No synopsis available from Open Library.").foregroundStyle(Color.textSecondary)
                }
                if model.isLoading { SwiftUI.ProgressView("Loading synopsis…") }
                if let error = model.error {
                    Text(error).font(AppTypography.caption)
                    Button("Retry") { request += 1 }
                        .frame(minHeight: AppLayout.minimumTapTarget)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(AppTypography.caption)
        .frame(minHeight: AppLayout.minimumTapTarget)
        .task(id: "\(expanded)-\(request)") {
            guard expanded, !loaded || model.error != nil, let repository else { return }
            await model.load(using: repository, scope: scope, synopsisOnly: true)
            if !Task.isCancelled { loaded = true }
        }
    }
}
