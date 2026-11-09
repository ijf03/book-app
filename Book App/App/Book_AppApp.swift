import SwiftUI
import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    lazy var container = AppContainer()
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct Book_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    var body: some Scene {
        WindowGroup {
            AppStartupView(makeContainer: { delegate.container })
        }
    }
}

private struct AppStartupView: View {
    let makeContainer: () -> AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var container: AppContainer?
    @State private var logoAppeared = false

    var body: some View {
        ZStack {
            if let container {
                AuthenticationGateView(container: container)
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
            container = makeContainer()
        }
    }
}
