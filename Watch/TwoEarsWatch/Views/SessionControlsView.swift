import SwiftUI

/// The second live page: a large End control and the session facts that don't belong on the ring.
struct SessionControlsView: View {
    @Environment(SessionManager.self) private var session

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Button("End", systemImage: "xmark", action: endSession)
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.bold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(.red)
                Text("End")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Label(session.intent.title, systemImage: session.intent.symbolName)
                    .font(.footnote)
                Text("^[\(session.nudgeCount) nudge](inflect: true)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if session.isLowBattery {
                    Label("Low battery", systemImage: "battery.25percent")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func endSession() {
        session.end(reason: .manual)
    }
}
