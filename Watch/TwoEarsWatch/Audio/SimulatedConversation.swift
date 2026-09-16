import Foundation

/// A scripted two-person conversation, generated one 100 ms window at a time.
/// Loud tone = wearer, quiet tone = partner, noise = nobody. Every tenth window dips to
/// the noise level so the classifier's noise floor stays anchored, as it does with real breaths.
enum SimulatedConversation {
    struct Segment: Sendable {
        /// dBFS of the tone, or nil for room noise only.
        var level: Double?
        var seconds: Int
    }

    static let wearerDb = -20.0
    static let partnerDb = -48.0
    static let noiseDb = -60.0
    static let sampleRate = 16000.0
    static let samplesPerWindow = 1600
    static let toneHz = 200.0

    /// About four minutes; the wearer talks too much early on, then listens.
    static let script: [Segment] = [
        Segment(level: nil, seconds: 3),
        Segment(level: wearerDb, seconds: 25),
        Segment(level: partnerDb, seconds: 12),
        Segment(level: wearerDb, seconds: 35),
        Segment(level: partnerDb, seconds: 10),
        Segment(level: wearerDb, seconds: 30),
        Segment(level: nil, seconds: 4),
        Segment(level: partnerDb, seconds: 40),
        Segment(level: wearerDb, seconds: 8),
        Segment(level: partnerDb, seconds: 45),
        Segment(level: nil, seconds: 3),
        Segment(level: wearerDb, seconds: 12),
        Segment(level: partnerDb, seconds: 30),
    ]

    static let totalWindows = script.reduce(0) { $0 + $1.seconds * 10 }

    /// Samples for window `window` (wrapping around the script), advancing the tone phase and noise seed.
    static func chunk(window: Int, sampleIndex: inout Int, seed: inout UInt64) -> [Float] {
        var cursor = window % totalWindows
        var level: Double?
        var indexInSegment = 0
        for segment in script {
            let count = segment.seconds * 10
            if cursor < count {
                level = segment.level
                indexInSegment = cursor
                break
            }
            cursor -= count
        }
        let out: [Float]
        if let level, indexInSegment % 10 != 9 {
            out = sine(dbfs: level, phase: sampleIndex)
        } else {
            out = noise(dbfs: noiseDb, seed: &seed)
        }
        sampleIndex += samplesPerWindow
        return out
    }

    static func sine(dbfs: Double, phase: Int) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return (0..<samplesPerWindow).map { i in
            Float(amplitude * sin(2 * .pi * toneHz * Double(i + phase) / sampleRate))
        }
    }

    static func noise(dbfs: Double, seed: inout UInt64) -> [Float] {
        var raw = [Double](repeating: 0, count: samplesPerWindow)
        for i in raw.indices {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            raw[i] = Double(seed >> 11) / Double(1 << 53) * 2 - 1
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(samplesPerWindow)).squareRoot()
        let gain = pow(10, dbfs / 20) / rms
        return raw.map { Float($0 * gain) }
    }
}
