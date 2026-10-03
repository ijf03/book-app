import SwiftUI

struct ProgressDashboardView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Progress")
            }
            .navigationTitle("Stats & Goals")
        }
    }
}

#Preview {
    ProgressDashboardView()
}
