import SwiftData
import SwiftUI

@main
struct TwoEarsWatchApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: SessionRecord.self)
        } catch {
            fatalError("Could not open the session store: \(error)")
        }
        SessionManager.shared.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(SessionManager.shared)
        }
        .modelContainer(container)
    }
}
