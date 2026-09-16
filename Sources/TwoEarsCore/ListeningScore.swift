import Foundation

/// A 0 to 100 rating of one session, in the spirit of Sleep Score: one number, a band, and a
/// breakdown the user can act on. Only sessions with a target and a share estimate are scored.
public struct ListeningScore: Equatable, Sendable {
    public enum Band: String, CaseIterable, Sendable {
        case excellent, good, ok, low, veryLow

        public init(value: Int) {
            switch value {
            case 90...: self = .excellent
            case 75...: self = .good
            case 60...: self = .ok
            case 40...: self = .low
            default: self = .veryLow
            }
        }
    }

    /// Points for staying under the target share. Fades to zero this far past the target.
    public static let sharePoints = 60.0
    public static let shareFadeSpan = 0.35
    /// Points for keeping stretches of your own speech short. Full credit at or under `stretchFreeSeconds`.
    public static let stretchPoints = 20.0
    public static let stretchFreeSeconds = 60.0
    public static let stretchFadeSeconds = 120.0
    /// Points for course-correcting after nudges. Full credit when no nudge was needed.
    public static let responsePoints = 20.0

    public let value: Int
    public let band: Band
    public let shareComponent: Int
    public let stretchComponent: Int
    public let responseComponent: Int

    /// nil when there is no target (Presenting) or no share estimate.
    public static func compute(talkShare: Double?, targetShare: Double?, longestStretchSeconds: Double,
                               nudgeCount: Int, nudgesJudged: Int, nudgesFollowed: Int) -> ListeningScore? {
        guard let talkShare, let targetShare else { return nil }

        let over = max(0, talkShare - targetShare)
        let share = sharePoints * clamp(1 - over / shareFadeSpan)

        let excess = max(0, longestStretchSeconds - stretchFreeSeconds)
        let stretch = stretchPoints * clamp(1 - excess / stretchFadeSeconds)

        let response: Double
        if nudgeCount == 0 {
            response = responsePoints
        } else if nudgesJudged == 0 {
            response = responsePoints / 2
        } else {
            response = responsePoints * Double(nudgesFollowed) / Double(nudgesJudged)
        }

        let shareInt = Int(share.rounded())
        let stretchInt = Int(stretch.rounded())
        let responseInt = Int(response.rounded())
        let total = min(100, max(0, shareInt + stretchInt + responseInt))
        return ListeningScore(value: total, band: Band(value: total), shareComponent: shareInt,
                              stretchComponent: stretchInt, responseComponent: responseInt)
    }

    private static func clamp(_ x: Double) -> Double {
        min(1, max(0, x))
    }
}
