import SwiftUI
import TwoEarsCore

/// The Listening Score in the Sleep Score idiom: a system circular gauge with the number inside.
struct ScoreGauge: View {
    var score: ListeningScore
    var scale: CGFloat = 1

    var body: some View {
        Gauge(value: Double(score.value), in: 0...100) {
            Text(verbatim: "")
        } currentValueLabel: {
            Text(score.value, format: .number)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.red, .orange, .yellow, .green]))
        .scaleEffect(scale)
        .frame(width: 50 * scale, height: 50 * scale)
        .accessibilityLabel("Listening Score")
        .accessibilityValue("\(score.value) out of 100, \(score.band.title)")
    }
}

extension ListeningScore.Band {
    var title: String {
        switch self {
        case .excellent: "Excellent"
        case .good: "Good"
        case .ok: "OK"
        case .low: "Low"
        case .veryLow: "Very Low"
        }
    }

    var tint: Color {
        switch self {
        case .excellent, .good: .green
        case .ok: .yellow
        case .low: .orange
        case .veryLow: .red
        }
    }
}
