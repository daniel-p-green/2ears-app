import Foundation

public enum TalkShare: Equatable, Sendable {
    /// Wearer voiced time over all attributed voiced time, 0...1.
    case value(Double)
    case uncertain
}

/// Trailing-window talk share with the spec's minimum-evidence gate.
public struct TalkShareEstimator: Sendable {
    private let config: ClassifierConfig
    /// nil = unvoiced window.
    private var ring: [Attribution?] = []
    private var writeIndex = 0
    private let capacity: Int

    public init(config: ClassifierConfig) {
        self.config = config
        capacity = max(1, config.shareWindowCount)
        ring.reserveCapacity(capacity)
    }

    public mutating func push(_ window: WindowStat) {
        let entry: Attribution? = window.voiced ? window.attribution : nil
        if ring.count < capacity {
            ring.append(entry)
        } else {
            ring[writeIndex] = entry
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    public var share: TalkShare {
        var user = 0, room = 0, uncertain = 0
        for entry in ring {
            switch entry {
            case .user?: user += 1
            case .room?: room += 1
            case .uncertain?: uncertain += 1
            case nil: break
            }
        }
        let voiced = user + room + uncertain
        guard voiced > 0 else { return .uncertain }
        if Double(voiced) * config.windowSeconds < config.minVoicedSec { return .uncertain }
        if Double(uncertain) / Double(voiced) > config.maxUncertainFraction { return .uncertain }
        guard user + room > 0 else { return .uncertain }
        return .value(Double(user) / Double(user + room))
    }
}
