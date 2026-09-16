import Foundation

/// Every tunable constant in the classifier. Defaults are the spec's starting values.
/// Decoding accepts partial JSON: unnamed keys keep their default.
public struct ClassifierConfig: Codable, Equatable, Sendable {
    public var sampleRate: Int = 16000
    public var windowMs: Int = 100
    public var floorTrailingSec: Double = 10
    public var floorPercentile: Double = 0.10
    public var vadMarginDb: Double = 8
    public var zcrMin: Double = 0.01
    public var zcrMax: Double = 0.20
    public var minBurstMs: Int = 800
    public var userBandDb: Double = 16
    public var uncertainMarginDb: Double = 3
    public var shareWindowSec: Double = 120
    public var minVoicedSec: Double = 15
    public var maxUncertainFraction: Double = 0.30

    public init() {}

    public static let `default` = ClassifierConfig()

    public var isDefault: Bool { self == ClassifierConfig.default }

    public var samplesPerWindow: Int { sampleRate * windowMs / 1000 }
    public var floorWindowCount: Int { Int(floorTrailingSec * 1000) / windowMs }
    public var minBurstWindows: Int { minBurstMs / windowMs }
    public var shareWindowCount: Int { Int(shareWindowSec * 1000) / windowMs }
    public var windowSeconds: Double { Double(windowMs) / 1000 }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClassifierConfig()
        sampleRate = try c.decodeIfPresent(Int.self, forKey: .sampleRate) ?? d.sampleRate
        windowMs = try c.decodeIfPresent(Int.self, forKey: .windowMs) ?? d.windowMs
        floorTrailingSec = try c.decodeIfPresent(Double.self, forKey: .floorTrailingSec) ?? d.floorTrailingSec
        floorPercentile = try c.decodeIfPresent(Double.self, forKey: .floorPercentile) ?? d.floorPercentile
        vadMarginDb = try c.decodeIfPresent(Double.self, forKey: .vadMarginDb) ?? d.vadMarginDb
        zcrMin = try c.decodeIfPresent(Double.self, forKey: .zcrMin) ?? d.zcrMin
        zcrMax = try c.decodeIfPresent(Double.self, forKey: .zcrMax) ?? d.zcrMax
        minBurstMs = try c.decodeIfPresent(Int.self, forKey: .minBurstMs) ?? d.minBurstMs
        userBandDb = try c.decodeIfPresent(Double.self, forKey: .userBandDb) ?? d.userBandDb
        uncertainMarginDb = try c.decodeIfPresent(Double.self, forKey: .uncertainMarginDb) ?? d.uncertainMarginDb
        shareWindowSec = try c.decodeIfPresent(Double.self, forKey: .shareWindowSec) ?? d.shareWindowSec
        minVoicedSec = try c.decodeIfPresent(Double.self, forKey: .minVoicedSec) ?? d.minVoicedSec
        maxUncertainFraction = try c.decodeIfPresent(Double.self, forKey: .maxUncertainFraction) ?? d.maxUncertainFraction
    }
}
