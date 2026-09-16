import Foundation

/// A scripted two-person conversation for the simulator, which has no microphone.
/// Loud tone = wearer, quiet tone = partner, noise = nobody. Every tenth window dips to
/// the noise level so the classifier's noise floor stays anchored, as it does with real breaths.
final class SimulatedAudioSource: AudioSource, @unchecked Sendable {
    private struct Segment {
        /// dBFS of the tone, or nil for room noise only.
        var level: Double?
        var seconds: Int
    }

    private static let wearer = -20.0
    private static let partner = -48.0
    private static let noise = -60.0
    private static let sampleRate = 16000.0
    private static let samplesPerWindow = 1600

    /// About four minutes; the wearer talks too much early on, then listens.
    private static let script: [Segment] = [
        Segment(level: nil, seconds: 3),
        Segment(level: wearer, seconds: 25),
        Segment(level: partner, seconds: 12),
        Segment(level: wearer, seconds: 35),
        Segment(level: partner, seconds: 10),
        Segment(level: wearer, seconds: 30),
        Segment(level: nil, seconds: 4),
        Segment(level: partner, seconds: 40),
        Segment(level: wearer, seconds: 8),
        Segment(level: partner, seconds: 45),
        Segment(level: nil, seconds: 3),
        Segment(level: wearer, seconds: 12),
        Segment(level: partner, seconds: 30),
    ]

    private var task: Task<Void, Never>?

    func start(handler: @escaping @Sendable ([Float]) -> Void) throws {
        task = Task.detached(priority: .userInitiated) {
            var window = 0
            var sampleIndex = 0
            var seed: UInt64 = 7
            let clock = ContinuousClock()
            let started = clock.now
            while !Task.isCancelled {
                let chunk = Self.chunk(window: window, sampleIndex: &sampleIndex, seed: &seed)
                handler(chunk)
                window += 1
                let next = started + .milliseconds(100 * window)
                try? await Task.sleep(until: next, clock: clock)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func chunk(window: Int, sampleIndex: inout Int, seed: inout UInt64) -> [Float] {
        let totalWindows = script.reduce(0) { $0 + $1.seconds * 10 }
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
            out = noise(dbfs: noise, seed: &seed)
        }
        sampleIndex += samplesPerWindow
        return out
    }

    private static func sine(dbfs: Double, phase: Int) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return (0..<samplesPerWindow).map { i in
            Float(amplitude * sin(2 * .pi * 200 * Double(i + phase) / sampleRate))
        }
    }

    private static func noise(dbfs: Double, seed: inout UInt64) -> [Float] {
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
