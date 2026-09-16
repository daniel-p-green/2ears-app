import Foundation

/// Slow-adapting noise floor: nearest-rank percentile of the trailing window levels.
public struct NoiseFloorTracker: Sendable {
    private var levels: [Double] = []
    private var writeIndex = 0
    private let capacity: Int
    private let percentile: Double
    /// Below this many samples the floor is the minimum seen, per spec.
    private let warmupCount = 20

    public init(config: ClassifierConfig) {
        capacity = max(1, config.floorWindowCount)
        percentile = config.floorPercentile
        levels.reserveCapacity(capacity)
    }

    public mutating func push(_ levelDb: Double) {
        if levels.count < capacity {
            levels.append(levelDb)
        } else {
            levels[writeIndex] = levelDb
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    public var floorDb: Double {
        guard !levels.isEmpty else { return LevelMeter.silenceFloorDb }
        if levels.count < warmupCount { return levels.min()! }
        let sorted = levels.sorted()
        // Nearest-rank: 1-based rank ceil(p * n), clamped to [1, n].
        let rank = min(sorted.count, max(1, Int((percentile * Double(sorted.count)).rounded(.up))))
        return sorted[rank - 1]
    }
}
