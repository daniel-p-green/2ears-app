import Foundation
import TwoEarsCore

/// The only thing that decides when the wrist gets tapped.
///
/// BELOW -> CROSSED on a single tap (120 s cooldown before another single tap),
/// CROSSED -> ESCALATED with a double tap if still over 60 s later (once per crossing),
/// back to BELOW when share drops under threshold minus hysteresis.
/// An uncertain share never changes state: the app never nudges on a guess.
struct NudgeController {
    enum Tap: Equatable {
        case single, double
    }

    private enum State: Equatable {
        case below
        case crossed(since: TimeInterval, escalated: Bool)
    }

    var threshold: Double?
    var hysteresis = 0.05
    var cooldown: TimeInterval = 120
    var escalationDelay: TimeInterval = 60

    private var state: State = .below
    private var lastSingleTapAt: TimeInterval?

    init(threshold: Double?) {
        self.threshold = threshold
    }

    var isOverThreshold: Bool {
        if case .crossed = state { return true }
        return false
    }

    /// Feed the latest share estimate; returns the tap to play, if any.
    mutating func update(share: TalkShare, at now: TimeInterval) -> Tap? {
        guard let threshold, case .value(let value) = share else { return nil }
        switch state {
        case .below:
            guard value > threshold else { return nil }
            state = .crossed(since: now, escalated: false)
            if let last = lastSingleTapAt, now - last < cooldown { return nil }
            lastSingleTapAt = now
            return .single
        case .crossed(let since, let escalated):
            if value < threshold - hysteresis {
                state = .below
                return nil
            }
            if !escalated, now - since >= escalationDelay {
                state = .crossed(since: since, escalated: true)
                return .double
            }
            return nil
        }
    }
}
