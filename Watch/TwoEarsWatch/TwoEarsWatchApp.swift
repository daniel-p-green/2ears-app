import SwiftData
import SwiftUI

@main
struct TwoEarsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(SessionManager.shared)
        }
        .modelContainer(for: SessionRecord.self)
    }
}
