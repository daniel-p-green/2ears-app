import SwiftUI

/// A start row in the system list idiom: tinted symbol, title, one-line detail.
struct IntentCard: View {
    var intent: SessionIntent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: intent.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(intent.title)
                    .font(.headline)
                Text(intent.cardDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts a session")
    }
}
