import SwiftUI

struct RootView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            switch session.phase {
            case .idle, .starting:
                StartView()
            case .active:
                ActiveSessionView()
            case .ended:
                if let summary = session.lastSummary {
                    SummaryView(summary: summary, isLive: true)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.appBecameActive()
            }
        }
    }
}
