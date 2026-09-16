import Foundation

/// Voice activity detection: level margin over the noise floor plus a zero-crossing band,
/// then burst rejection. Emits windows with a delay of up to `minBurstWindows`.
public struct VadClassifier: Sendable {
    private let config: ClassifierConfig
    private var pending: [WindowStat] = []
    private var inConfirmedRun = false

    public init(config: ClassifierConfig) {
        self.config = config
    }

    /// The instantaneous decision before burst rejection.
    public func rawVoiced(_ w: WindowStat) -> Bool {
        w.levelDb > w.noiseFloorDb + config.vadMarginDb
            && w.zcr >= config.zcrMin
            && w.zcr <= config.zcrMax
    }

    /// Returns the windows finalized by this input, in index order. May be empty.
    public mutating func process(_ window: WindowStat) -> [WindowStat] {
        var w = window
        if rawVoiced(w) {
            if inConfirmedRun {
                w.voiced = true
                return [w]
            }
            pending.append(w)
            if pending.count >= config.minBurstWindows {
                inConfirmedRun = true
                return flushPending(voiced: true)
            }
            return []
        }
        inConfirmedRun = false
        var out = flushPending(voiced: false)
        w.voiced = false
        out.append(w)
        return out
    }

    /// End of stream: any unconfirmed run is too short by definition.
    public mutating func finish() -> [WindowStat] {
        inConfirmedRun = false
        return flushPending(voiced: false)
    }

    private mutating func flushPending(voiced: Bool) -> [WindowStat] {
        let out = pending.map { w -> WindowStat in
            var v = w
            v.voiced = voiced
            return v
        }
        pending.removeAll(keepingCapacity: true)
        return out
    }
}
