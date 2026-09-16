import SwiftUI
import TwoEarsCore

/// The one thing on screen during a conversation: your share of it, as a ring.
struct ShareRing: View {
    var share: TalkShare
    var threshold: Double?
    var isOverThreshold: Bool
    var lineWidth: CGFloat = 12
    /// Hides the centre text for small decorative rings.
    var showsLabel = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var value: Double? {
        if case .value(let v) = share { return v }
        return nil
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if let value {
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(ringColor.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if let threshold {
                thresholdMark(at: threshold)
            }
            if showsLabel {
                label
                    .padding(lineWidth + 6)
            }
        }
        .padding(lineWidth / 2)
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : .smooth, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your share of the conversation")
        .accessibilityValue(accessibilityValue)
    }

    private var label: some View {
        VStack(spacing: 0) {
            if let value {
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                Text("talking")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("···")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("Listening")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }

    private var ringColor: Color {
        isOverThreshold ? .orange : .blue
    }

    private var accessibilityValue: String {
        guard let value else { return "Not enough evidence yet" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func thresholdMark(at threshold: Double) -> some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width, geometry.size.height) / 2
            Capsule()
                .fill(.primary.opacity(0.7))
                .frame(width: 3, height: lineWidth + 6)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - radius)
                .rotationEffect(.degrees(threshold * 360))
        }
    }
}
