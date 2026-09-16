import Charts
import SwiftUI
import TwoEarsCore

struct SummaryView: View {
    var summary: SessionSummaryData
    /// True right after a session; shows the Done button that returns to the start screen.
    var isLive: Bool

    @Environment(SessionManager.self) private var session

    var body: some View {
        List {
            Section {
                hero
                    .padding(.vertical, 6)
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
            } footer: {
                Text(summary.endReason.title)
            }

            if isLive {
                Button("Done") {
                    session.dismissSummary()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(isLive ? "Summary" : summary.endedAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarBackButtonHidden(isLive)
        .containerBackground(Color.accentColor.gradient, for: .navigation)
    }

    private var hero: some View {
        HStack(spacing: 12) {
            ShareRing(share: summary.talkShare.map { .value($0) } ?? .uncertain,
                      threshold: summary.intent.threshold,
                      isOverThreshold: summary.metTarget == false,
                      lineWidth: 8,
                      showsLabel: false)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                if let share = summary.talkShare {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("talking")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unclear")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Too noisy to attribute")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let threshold = summary.intent.threshold {
                    Label(targetText(threshold),
                          systemImage: summary.metTarget == true ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.caption2)
                        .foregroundStyle(summary.metTarget == true ? .green : .secondary)
                        .padding(.top, 2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var sparkline: some View {
        Chart {
            ForEach(Array(summary.perMinuteShare.enumerated()), id: \.offset) { minute, value in
                if let value {
                    LineMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                }
            }
            if let threshold = summary.intent.threshold {
                RuleMark(y: .value("Target", threshold))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Color.accentColor)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityLabel("Talk share per minute")
    }

    private func targetText(_ threshold: Double) -> String {
        let target = threshold.formatted(.percent.precision(.fractionLength(0)))
        return summary.metTarget == true ? "Under \(target)" : "Over \(target)"
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}
