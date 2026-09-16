import SwiftUI

/// Two vertical pages, like Workout: the ring, then the controls.
struct ActiveSessionView: View {
    private enum Page {
        case ring, controls
    }

    @Environment(SessionManager.self) private var session
    @State private var page = Page.ring

    var body: some View {
        TabView(selection: $page) {
            ringPage
                .tag(Page.ring)
            SessionControlsView()
                .tag(Page.controls)
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
        session.isOverThreshold ? Theme.over : Theme.glow
    }
}
