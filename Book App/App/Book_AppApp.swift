import SwiftUI

@main
struct Book_AppApp: App {
    var body: some Scene {
        WindowGroup { AppStartupView() }
    }
}

private struct AppStartupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var container: AppContainer?
    @State private var logoAppeared = false

    var body: some View {
        ZStack {
            if let container {
                RootView(
                    bookRepository: container.bookRepository,
                    libraryStore: container.libraryStore,
                    readingSessionStore: container.readingSessionStore
                )
                .environment(container.router)
                .environment(container.readingSessionStore)
                .environment(container.bookContentStore)
            } else {
                ZStack {
                    Color("AppAccent").ignoresSafeArea()
                    Image("AppLogo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 140)
                        .scaleEffect(reduceMotion || logoAppeared ? 1 : 0.92)
                        .opacity(logoAppeared ? 1 : 0.7)
                        .accessibilityLabel("Loading your library")
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                logoAppeared = true
            }
        }
        .task {
            guard container == nil else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            let loadedContainer = AppContainer()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                container = loadedContainer
            }
        }
    }
}
