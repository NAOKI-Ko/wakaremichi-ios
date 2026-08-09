import SwiftUI
import SwiftData

@main
struct KareMichiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .modelContainer(for: DailyRun.self)
    }
}
