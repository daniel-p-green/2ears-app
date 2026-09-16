import Charts
import SwiftUI

struct SummaryView: View {
    var summary: SessionSummaryData
    /// True right after a session; shows the Done button that returns to the start screen.
    var isLive: Bool

    @Environment(SessionManager.self) private var session

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if let share = summary.talkShare {
                        Text(share, format: .percent.precision(.fractionLength(0)))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("of the conversation")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not enough to tell")
                            .font(.headline)
                        Text("The room was too noisy or too quiet to attribute.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let threshold = summary.intent.threshold {
                        Label(targetText(threshold), systemImage: summary.metTarget == true ? "checkmark.circle.fill" : "circle")
                            .font(.footnote)
                            .foregroundStyle(summary.metTarget == true ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if summary.perMinuteShare.contains(where: { $0 != nil }) {
                Section("Over Time") {
                    sparkline
                        .frame(height: 56)
                        .padding(.vertical, 4)
                }
            }

            Section {
                LabeledContent("Longest stretch", value: durationText(summary.longestUserStretch))
                LabeledContent("Nudges", value: summary.nudgeCount.formatted())
                if summary.nudgeCount > 0 {
                    LabeledContent("Course-corrected", value: "\(summary.nudgesFollowed) of \(summary.nudgeCount)")
                }
                LabeledContent("Uncertain", value: summary.uncertainFraction.formatted(.percent.precision(.fractionLength(0))))
                LabeledContent("Length", value: durationText(summary.duration))
            }

            Section {
                Text(summary.endReason.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isLive {
                Section {
                    Button("Done") {
                        session.dismissSummary()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle(isLive ? "Summary" : summary.endedAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarBackButtonHidden(isLive)
    }

    private var sparkline: some View {
        Chart {
            ForEach(Array(summary.perMinuteShare.enumerated()), id: \.offset) { minute, value in
                if let value {
                    LineMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.blue.opacity(0.15))
                }
            }
            if let threshold = summary.intent.threshold {
                RuleMark(y: .value("Target", threshold))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
            }
        }
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityLabel("Talk share per minute")
    }

    private func targetText(_ threshold: Double) -> String {
        let target = threshold.formatted(.percent.precision(.fractionLength(0)))
        return summary.metTarget == true ? "Under your \(target) target" : "Target was under \(target)"
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}
