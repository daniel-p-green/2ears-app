import SwiftData
import SwiftUI

@main
struct TwoEarsWatchApp: App {
    @State private var session = SessionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        .modelContainer(for: SessionRecord.self)
    }
}
