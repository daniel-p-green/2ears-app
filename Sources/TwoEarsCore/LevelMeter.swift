import Foundation

public enum LevelMeter {
    /// Reported for an all-zero or empty block instead of negative infinity.
    public static let silenceFloorDb: Double = -120

    /// RMS of the block in dBFS, clamped at `silenceFloorDb`.
    public static func levelDb(_ samples: ArraySlice<Float>) -> Double {
        guard !samples.isEmpty else { return silenceFloorDb }
        var sum: Double = 0
        for s in samples { sum += Double(s) * Double(s) }
        let rms = (sum / Double(samples.count)).squareRoot()
        guard rms > 0 else { return silenceFloorDb }
        return max(silenceFloorDb, 20 * log10(rms))
    }

    /// Sign changes between consecutive samples, divided by sample count.
    public static func zeroCrossingRate(_ samples: ArraySlice<Float>) -> Double {
        guard samples.count > 1 else { return 0 }
        var crossings = 0
        var previousNonNegative = samples[samples.startIndex] >= 0
        for s in samples.dropFirst() {
            let nonNegative = s >= 0
            if nonNegative != previousNonNegative { crossings += 1 }
            previousNonNegative = nonNegative
        }
        return Double(crossings) / Double(samples.count)
    }
}
