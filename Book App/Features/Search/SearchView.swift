import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Search")
            }
            .navigationTitle("Find Books")
        }
    }
}

#Preview {
    SearchView()
}
