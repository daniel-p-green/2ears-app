import SwiftUI

struct ActiveSessionView: View {
    @Environment(SessionManager.self) private var session

    var body: some View {
        VStack(spacing: 6) {
            ShareRing(share: session.share,
                      threshold: session.intent.threshold,
                      isOverThreshold: session.isOverThreshold)
                .frame(maxHeight: 130)
            if let startedAt = session.startedAt {
                Text(startedAt, style: .timer)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .navigationTitle(session.intent.title)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("End", systemImage: "stop.fill", role: .destructive) {
                    session.end(reason: .manual)
                }
                .tint(.red)
            }
        }
    }
}
