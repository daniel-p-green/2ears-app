import Foundation

/// Synthetic signal helpers. All functions return Float samples at 16 kHz unless stated.
enum Signal {
    static let sampleRate = 16000

    /// Sine at `hz` with peak amplitude `amplitude`, `count` samples, starting at `phase` samples in.
    static func sine(hz: Double, amplitude: Double, count: Int, phase: Int = 0) -> [Float] {
        (0..<count).map { i in
            Float(amplitude * sin(2 * .pi * hz * Double(i + phase) / Double(sampleRate)))
        }
    }

    /// Sine whose RMS is `dbfs` decibels below full scale. RMS of a sine is amplitude / sqrt(2).
    static func sine(hz: Double, dbfs: Double, count: Int, phase: Int = 0) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return sine(hz: hz, amplitude: amplitude, count: count, phase: phase)
    }

    /// Deterministic white noise with RMS at `dbfs`. Uses a fixed LCG so tests are repeatable.
    static func noise(dbfs: Double, count: Int, seed: UInt64 = 1) -> [Float] {
        var state = seed
        var raw: [Double] = []
        raw.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            raw.append(Double(state >> 11) / Double(1 << 53) * 2 - 1)
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
        let gain = pow(10, dbfs / 20) / rms
        return raw.map { Float($0 * gain) }
    }

    static func silence(count: Int) -> [Float] { [Float](repeating: 0, count: count) }

    /// `windows` 100 ms windows of a 200 Hz tone at `dbfs`, with every tenth window replaced by
    /// noise at `noiseDb`. The dips keep the noise floor anchored at the noise level (the floor is a
    /// 10th percentile over 100 windows) while the nine-window runs stay above the 800 ms burst minimum.
    static func dippedTone(dbfs: Double, noiseDb: Double, windows: Int, phase: Int = 0) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(windows * 1600)
        for w in 0..<windows {
            if w % 10 == 9 {
                out += noise(dbfs: noiseDb, count: 1600, seed: UInt64(w + 7))
            } else {
                out += sine(hz: 200, dbfs: dbfs, count: 1600, phase: phase + out.count)
            }
        }
        return out
    }
}
