import Foundation

@MainActor
final class AppContainer {
    
    let router: AppRouter
    
    init() {
        self.router = AppRouter()
    }
}
