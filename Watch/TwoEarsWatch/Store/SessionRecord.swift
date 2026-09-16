import Foundation
import SwiftData

/// Persisted session summary. Percentages, durations, and timestamps only.
@Model
final class SessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var intentRawValue: String
    var talkShare: Double?
    var uncertainFraction: Double
    var longestUserStretch: TimeInterval
    var nudgeCount: Int
    var nudgesFollowed: Int
    /// One entry per minute; a negative value means the estimator was uncertain that minute.
    var perMinuteShareStorage: [Double]
    var endReasonRawValue: String

    init(summary: SessionSummaryData) {
        id = summary.id
        startedAt = summary.startedAt
        endedAt = summary.endedAt
        intentRawValue = summary.intent.rawValue
        talkShare = summary.talkShare
        uncertainFraction = summary.uncertainFraction
        longestUserStretch = summary.longestUserStretch
        nudgeCount = summary.nudgeCount
        nudgesFollowed = summary.nudgesFollowed
        perMinuteShareStorage = summary.perMinuteShare.map { $0 ?? -1 }
        endReasonRawValue = summary.endReason.rawValue
    }

    var intent: SessionIntent { SessionIntent(rawValue: intentRawValue) ?? .listen }

    var summary: SessionSummaryData {
        SessionSummaryData(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            intent: intent,
            talkShare: talkShare,
            uncertainFraction: uncertainFraction,
            longestUserStretch: longestUserStretch,
            nudgeCount: nudgeCount,
            nudgesFollowed: nudgesFollowed,
            perMinuteShare: perMinuteShareStorage.map { $0 < 0 ? nil : $0 },
            endReason: SessionEndReason(rawValue: endReasonRawValue) ?? .manual)
    }
}
