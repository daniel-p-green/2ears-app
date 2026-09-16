import Foundation
import TwoEarsCore
@testable import TwoEarsLabKit

/// Builds a fake recording that follows a turn script, for end-to-end tests.
enum SyntheticSession {
    static let sampleRate = 16000
    static let noiseDb = -60.0
    static let youDb = -20.0
    static let partnerDb = -50.0
    static let bothDb = -44.0
    static let toneHz = 200.0

    static func sine(dbfs: Double, count: Int, phase: Int) -> [Float] {
        let amplitude = pow(10, dbfs / 20) * 2.0.squareRoot()
        return (0..<count).map { i in
            Float(amplitude * sin(2 * .pi * toneHz * Double(i + phase) / Double(sampleRate)))
        }
    }

    static func noise(dbfs: Double, count: Int, seed: inout UInt64) -> [Float] {
        var raw: [Double] = []
        raw.reserveCapacity(count)
        for _ in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            raw.append(Double(seed >> 11) / Double(1 << 53) * 2 - 1)
        }
        let rms = (raw.reduce(0) { $0 + $1 * $1 } / Double(count)).squareRoot()
        let gain = pow(10, dbfs / 20) / rms
        return raw.map { Float($0 * gain) }
    }

    /// Samples for the whole script. Speech blocks dip to noise on every tenth window.
    static func samples(for script: TurnScript, config: ClassifierConfig = .default) -> [Float] {
        var out: [Float] = []
        var seed: UInt64 = 42
        let n = config.samplesPerWindow
        for block in script.timeline() {
            let windows = block.durationMs / config.windowMs
            for w in 0..<windows {
                let level: Double?
                switch block.label {
                case .silence: level = nil
                case .you: level = youDb
                case .partner: level = partnerDb
                case .both: level = bothDb
                }
                if let level, w % 10 != 9 {
                    out += sine(dbfs: level, count: n, phase: out.count)
                } else {
                    out += noise(dbfs: noiseDb, count: n, seed: &seed)
                }
            }
        }
        return out
    }

    /// Writes audio.wav and labels.json into `dir` and returns the labels.
    @discardableResult
    static func write(script: TurnScript = .default, condition: String = "quiet", device: String = "synthetic",
                      sampleRate: Int = 16000, to dir: URL) throws -> SessionLabels {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try WavFile.write(samples: samples(for: script), sampleRate: SyntheticSession.sampleRate,
                          to: dir.appendingPathComponent(SessionFiles.audioName))
        let labels = SessionLabels(recordedAt: Date(timeIntervalSince1970: 1_800_000_000), condition: condition,
                                   device: device, notes: "synthetic fixture", sampleRate: sampleRate,
                                   scriptName: script.name, blocks: script.timeline(), endedEarlyAtMs: nil)
        try SessionFiles.writeLabels(labels, in: dir)
        return labels
    }
}
