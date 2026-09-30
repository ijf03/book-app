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
