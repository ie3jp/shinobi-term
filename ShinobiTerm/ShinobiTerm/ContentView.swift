import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "terminal")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)

                Text("Shinobi Term")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("SSH terminal that speaks your language")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
