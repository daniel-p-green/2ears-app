import Foundation

/// Runs raw samples through level, noise floor, VAD, attribution, and talk share.
/// Accepts chunks of any size. Call `finish()` at end of stream.
public final class Pipeline {
    public let config: ClassifierConfig
    private var buffer: [Float] = []
    private var nextIndex = 0
    private var floor: NoiseFloorTracker
    private var vad: VadClassifier
    private var estimator: TalkShareEstimator

    public init(config: ClassifierConfig) {
        self.config = config
        floor = NoiseFloorTracker(config: config)
        vad = VadClassifier(config: config)
        estimator = TalkShareEstimator(config: config)
        buffer.reserveCapacity(config.samplesPerWindow * 2)
    }

    /// Talk share as of the last emitted window.
    public var currentShare: TalkShare { estimator.share }

    /// Windows completed by this chunk, in index order. Windows held by burst rejection
    /// are emitted by a later call or by `finish()`.
    public func process(_ samples: [Float]) -> [WindowStat] {
        buffer.append(contentsOf: samples)
        let n = config.samplesPerWindow
        var out: [WindowStat] = []
        var start = 0
        while buffer.count - start >= n {
            let slice = buffer[start..<(start + n)]
            out += analyze(slice)
            start += n
        }
        if start > 0 { buffer.removeFirst(start) }
        return out
    }

    /// Resolves any pending voiced run as unvoiced and drops a partial trailing window.
    public func finish() -> [WindowStat] {
        buffer.removeAll(keepingCapacity: true)
        return emit(vad.finish())
    }

    private func analyze(_ slice: ArraySlice<Float>) -> [WindowStat] {
        let level = LevelMeter.levelDb(slice)
        let zcr = LevelMeter.zeroCrossingRate(slice)
        floor.push(level)
        let window = WindowStat(index: nextIndex, startMs: nextIndex * config.windowMs,
                                levelDb: level, noiseFloorDb: floor.floorDb, zcr: zcr,
                                voiced: false, attribution: nil)
        nextIndex += 1
        return emit(vad.process(window))
    }

    private func emit(_ windows: [WindowStat]) -> [WindowStat] {
        windows.map { w in
            var v = w
            v.attribution = v.voiced
                ? AttributionClassifier.classify(levelDb: v.levelDb, noiseFloorDb: v.noiseFloorDb, config: config)
                : nil
            estimator.push(v)
            return v
        }
    }
}
