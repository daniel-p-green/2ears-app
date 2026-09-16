import Foundation

/// Haptic parameters. Every value is user-tunable in settings; these are the spec's starting values.
public struct NudgeConfig: Equatable, Sendable {
    /// Share of the trailing window that triggers a nudge. nil disables nudges (Presenting intent).
    public var threshold: Double?
    /// Share must fall this far below the threshold before the controller re-arms.
    public var hysteresis: Double
    /// Minimum seconds between two single taps.
    public var cooldownSeconds: Double
    /// Seconds over the threshold before the one-time double tap.
    public var escalationSeconds: Double

    public init(threshold: Double?, hysteresis: Double = 0.05,
                cooldownSeconds: Double = 120, escalationSeconds: Double = 60) {
        self.threshold = threshold
        self.hysteresis = hysteresis
        self.cooldownSeconds = cooldownSeconds
        self.escalationSeconds = escalationSeconds
    }
}

/// The only thing that decides when the wrist gets tapped.
///
/// BELOW -> CROSSED on a single tap (subject to cooldown), CROSSED -> ESCALATED with a double tap
/// if still over after `escalationSeconds` (once per crossing), and back to BELOW once share drops
/// under threshold minus hysteresis. An uncertain share never changes state: never nudge on a guess.
public struct NudgeController: Equatable, Sendable {
    public enum Tap: Equatable, Sendable {
        case single, double
    }

    public enum State: Equatable, Sendable {
        case below, crossed, escalated
    }

    public let config: NudgeConfig
    public private(set) var state: State = .below
    private var crossedAt: Double?
    private var lastSingleTapAt: Double?

    public init(config: NudgeConfig) {
        self.config = config
    }

    public var isOverThreshold: Bool { state != .below }

    /// Feed the latest estimate at `now` seconds into the session; returns the tap to play, if any.
    public mutating func update(share: TalkShare, at now: Double) -> Tap? {
        guard let threshold = config.threshold, case .value(let value) = share else { return nil }
        switch state {
        case .below:
            guard value > threshold else { return nil }
            state = .crossed
            crossedAt = now
            if let last = lastSingleTapAt, now - last < config.cooldownSeconds { return nil }
            lastSingleTapAt = now
            return .single
        case .crossed:
            if value < threshold - config.hysteresis {
                state = .below
                return nil
            }
            if let crossedAt, now - crossedAt >= config.escalationSeconds {
                state = .escalated
                return .double
            }
            return nil
        case .escalated:
            if value < threshold - config.hysteresis {
                state = .below
            }
            return nil
        }
    }
}
