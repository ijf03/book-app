import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Library")
            }
            .navigationTitle("My Library")
        }
    }
}

#Preview {
    LibraryView()
}
