import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            switch session.phase {
            case .idle:
                StartView()
            case .active:
                ActiveSessionView()
            case .ended:
                if let summary = session.lastSummary {
                    SummaryView(summary: summary, isLive: true)
                }
            }
        }
        .onChange(of: session.lastSummary?.id) { _, id in
            guard id != nil, let summary = session.lastSummary else { return }
            try? SessionStore.save(summary, in: context)
        }
    }
}
