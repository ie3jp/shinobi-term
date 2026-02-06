import SwiftData
import SwiftUI

@main
struct ShinobiTermApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ConnectionProfile.self, AppSettings.self])
    }
}
