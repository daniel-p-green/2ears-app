import Foundation

enum SessionEndReason: String, Codable, Sendable {
    case manual, autoSilence, battery, interruption

    var title: String {
        switch self {
        case .manual: "Ended by you"
        case .autoSilence: "Ended after 3 min of quiet"
        case .battery: "Ended for battery"
        case .interruption: "Interrupted"
        }
    }
}

/// Everything the summary card needs. Derived from per-window aggregates, never from audio.
struct SessionSummaryData: Identifiable, Equatable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var intent: SessionIntent
    /// nil when the session never accumulated enough evidence for a number.
    var talkShare: Double?
    var uncertainFraction: Double
    var longestUserStretch: TimeInterval
    var nudgeCount: Int
    var nudgesFollowed: Int
    /// One entry per elapsed minute; nil where the estimator was uncertain.
    var perMinuteShare: [Double?]
    var endReason: SessionEndReason

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

    /// True when the session finished inside the intent's target band.
    var metTarget: Bool? {
        guard let talkShare, let threshold = intent.threshold else { return nil }
        return talkShare <= threshold
    }
}
