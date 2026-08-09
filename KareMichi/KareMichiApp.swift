import SwiftUI
import SwiftData

@main
struct KareMichiApp: App {
    init() {
        Ads.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
        .modelContainer(for: DailyRun.self)
    }
}
