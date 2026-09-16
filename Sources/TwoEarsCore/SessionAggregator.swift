import Foundation

/// Running per-session aggregates over emitted windows. Holds no audio and no per-window history
/// beyond what the summary needs: counts, the longest wearer stretch, one share sample per minute,
/// and whether each nudge was followed by a drop in share.
///
/// All times are pipeline seconds (derived from window timestamps), not wall-clock time, so a
/// paused microphone does not read as silence.
public struct SessionAggregator: Equatable, Sendable {
    /// A nudge counts as followed when share drops by at least this within `followWindowSeconds`.
    public var followedDrop: Double = 0.05
    public var followWindowSeconds: Double = 120
    /// Pauses of up to this many windows do not break a stretch of the wearer's speech.
    public var stretchGapWindows: Int = 10

    public private(set) var totalWindows = 0
    public private(set) var uncertainWindows = 0
    /// Pipeline seconds covered so far: the end of the last recorded window.
    public private(set) var pipelineSeconds: Double = 0
    /// Pipeline seconds of the most recent voiced window.
    public private(set) var lastVoicedAt: Double = 0
    public private(set) var longestUserStretchSeconds: Double = 0
    /// One entry per completed minute (plus the final partial minute after `finish`);
    /// nil where the estimator was uncertain at that point.
    public private(set) var perMinuteShare: [Double?] = []
    public private(set) var nudgeCount = 0
    public private(set) var nudgesFollowed = 0

    private var currentStretchWindows = 0
    private var gapWindows = 0
    private var pendingFollowChecks: [PendingCheck] = []

    private struct PendingCheck: Equatable, Sendable {
        var due: Double
        var shareAtNudge: Double
    }

    public init() {}

    public var uncertainFraction: Double {
        totalWindows > 0 ? Double(uncertainWindows) / Double(totalWindows) : 0
    }

    public mutating func record(_ windows: [WindowStat], config: ClassifierConfig) {
        for window in windows {
            totalWindows += 1
            pipelineSeconds = max(pipelineSeconds, Double(window.startMs + config.windowMs) / 1000)
            if window.voiced {
                lastVoicedAt = Double(window.startMs) / 1000
            }
            if window.attribution == .uncertain {
                uncertainWindows += 1
            }
            if window.attribution == .user {
                currentStretchWindows += 1 + gapWindows
                gapWindows = 0
                longestUserStretchSeconds = max(longestUserStretchSeconds,
                                                Double(currentStretchWindows) * config.windowSeconds)
            } else if currentStretchWindows > 0 {
                gapWindows += 1
                if gapWindows > stretchGapWindows {
                    currentStretchWindows = 0
                    gapWindows = 0
                }
            }
        }
    }

    /// Call when a nudge fires so its follow-through can be judged later.
    public mutating func recordNudge(at elapsed: Double, share: TalkShare) {
        nudgeCount += 1
        if case .value(let value) = share {
            pendingFollowChecks.append(PendingCheck(due: elapsed + followWindowSeconds, shareAtNudge: value))
        }
    }

    /// Call about once a second. Samples the share at each minute boundary and judges due nudges.
    public mutating func tick(elapsed: Double, share: TalkShare) {
        let minute = Int(elapsed / 60)
        while perMinuteShare.count < minute {
            perMinuteShare.append(share.valueOrNil)
        }
        resolveFollowChecks(upTo: elapsed, share: share)
    }

    /// Call at end of session. Samples the final partial minute and judges nudges that had at least
    /// half their follow window to play out; more recent ones are left unjudged rather than scored
    /// against a window that never happened.
    public mutating func finish(elapsed: Double, share: TalkShare) {
        tick(elapsed: elapsed, share: share)
        if Double(perMinuteShare.count) * 60 < elapsed {
            perMinuteShare.append(share.valueOrNil)
        }
        resolveFollowChecks(upTo: elapsed + followWindowSeconds / 2, share: share)
        pendingFollowChecks.removeAll()
    }

    private mutating func resolveFollowChecks(upTo time: Double, share: TalkShare) {
        let due = pendingFollowChecks.filter { $0.due <= time }
        guard !due.isEmpty else { return }
        pendingFollowChecks.removeAll { $0.due <= time }
        guard let current = share.valueOrNil else { return }
        for check in due where current <= check.shareAtNudge - followedDrop {
            nudgesFollowed += 1
        }
    }
}

public extension TalkShare {
    /// The share as a number, or nil when uncertain.
    var valueOrNil: Double? {
        if case .value(let v) = self { return v }
        return nil
    }
}
