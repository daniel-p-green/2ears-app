import SwiftUI

/// Two vertical pages, like Workout: the ring, then the controls.
struct ActiveSessionView: View {
    @Environment(SessionManager.self) private var session
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            ringPage
                .tag(0)
            SessionControlsView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle {
            if let startedAt = session.startedAt {
                Text(startedAt, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .navigationBarBackButtonHidden()
        .containerBackground(glow.gradient, for: .navigation)
    }

    private var ringPage: some View {
        ShareRing(share: session.share,
                  threshold: session.intent.threshold,
                  isOverThreshold: session.isOverThreshold,
                  lineWidth: 14)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var glow: Color {
        session.isOverThreshold ? .orange : .accentColor
    }
}
