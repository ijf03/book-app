import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    
    enum Route: Hashable {
        case bookDetail(id: String)
        case updateProgress(bookID: String)
        case notes(bookID: String)
        case review(bookID: String)
    }
    
    struct SearchRequest: Equatable {
        let id = UUID()
        let author: String?
        let genre: String?
    }

    var searchRequest: SearchRequest?

    func explore(author: String? = nil, genre: String? = nil) {
        searchRequest = SearchRequest(author: author, genre: genre)
    }

    var path: [Route] = []
    
    func navigate(to route: Route) {
        path.append(route)
    }
    
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func goToRoot() {
        path.removeAll()
    }
}
