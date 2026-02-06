import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ConnectionListView()
                .tabItem {
                    Label("Connections", systemImage: "terminal")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.indigo)
        .preferredColorScheme(.dark)
    }
}
