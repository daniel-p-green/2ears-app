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
                if let score = summary.score {
                    ScoreHero(score: score, summary: summary)
                } else {
                    UnscoredHero(summary: summary)
                }
            }

            if let score = summary.score {
                Section("Breakdown") {
                    LabeledContent("Share", value: "\(score.shareComponent) of \(Int(ListeningScore.sharePoints))")
                    LabeledContent("Stretches", value: "\(score.stretchComponent) of \(Int(ListeningScore.stretchPoints))")
                    LabeledContent("Response", value: "\(score.responseComponent) of \(Int(ListeningScore.responsePoints))")
                }
            }

            if summary.perMinuteShare.compactMap({ $0 }).count >= 2 {
                Section("Over Time") {
                    SharePerMinuteChart(perMinuteShare: summary.perMinuteShare, threshold: summary.intent.threshold)
                        .frame(height: 56)
                        .padding(.vertical, 4)
                }
            }

            Section {
                LabeledContent("Talking", value: shareText)
                LabeledContent("Longest stretch", value: durationText(summary.longestUserStretch))
                LabeledContent("Nudges", value: summary.nudgeCount.formatted())
                if summary.nudgesJudged > 0 {
                    LabeledContent("Followed", value: "\(summary.nudgesFollowed) of \(summary.nudgesJudged)")
                } else if summary.nudgeCount > 0 {
                    LabeledContent("Followed", value: "Too soon to tell")
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
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(isLive ? "Summary" : summary.endedAt.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarBackButtonHidden(isLive)
        .containerBackground(Theme.glow.gradient, for: .navigation)
    }

    private var shareText: String {
        guard let share = summary.talkShare else { return "Unclear" }
        return share.formatted(.percent.precision(.fractionLength(0)))
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
    }
}

/// Score gauge beside the band and the one-line share verdict.
private struct ScoreHero: View {
    var score: ListeningScore
    var summary: SessionSummaryData

    var body: some View {
        VStack(spacing: 6) {
            ScoreGauge(score: score, scale: 1.8)
                .padding(.top, 6)
            Text(score.band.title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(score.band.tint)
            Text("Listening Score")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let threshold = summary.intent.threshold, let share = summary.talkShare {
                Text(verdict(share: share, threshold: threshold))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func verdict(share: Double, threshold: Double) -> String {
        let s = share.formatted(.percent.precision(.fractionLength(0)))
        let t = threshold.formatted(.percent.precision(.fractionLength(0)))
        return share <= threshold ? "\(s) talking, under \(t)" : "\(s) talking, over \(t)"
    }
}

/// Presenting sessions and sessions with no share estimate: the number without a grade.
private struct UnscoredHero: View {
    var summary: SessionSummaryData

    var body: some View {
        HStack(spacing: 12) {
            ShareRing(share: summary.talkShare.map { .value($0) } ?? .uncertain,
                      threshold: summary.intent.threshold,
                      isOverThreshold: false,
                      lineWidth: 8,
                      showsLabel: false)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                if let share = summary.talkShare {
                    Text(share, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(summary.intent == .presenting ? "talking, no score while presenting" : "talking")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unclear")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Too noisy to attribute")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
    }
}

private struct SharePerMinuteChart: View {
    var perMinuteShare: [Double?]
    var threshold: Double?

    var body: some View {
        Chart {
            ForEach(perMinuteShare.enumerated(), id: \.offset) { minute, value in
                if let value {
                    LineMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Minute", minute), y: .value("Share", value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.accentColor.opacity(0.15))
                }
            }
            if let threshold {
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
}
