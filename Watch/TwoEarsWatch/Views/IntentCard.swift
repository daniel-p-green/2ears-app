import SwiftUI

/// A Workout-style start card: one tap begins a session with this intent.
struct IntentCard: View {
    var intent: SessionIntent

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(intent.title)
                    .font(.title3.weight(.semibold))
                Text(intent.cardDetail)
                    .font(.footnote)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            Image(systemName: intent.symbolName)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts a session")
    }
}
