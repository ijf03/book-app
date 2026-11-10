import SwiftUI

enum AppGradients {
    /// A branded card wash layered over the semantic surface in either appearance.
    static let checkIn = LinearGradient(
        colors: [Color.appAccent.opacity(0.18), Color.appAccent.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
