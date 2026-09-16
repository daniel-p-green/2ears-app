import Foundation
import TwoEarsCore

public struct SessionInfo: Codable, Equatable, Sendable {
    public var sessionDir: String
    public var condition: String
    public var device: String
    public var recordedAt: Date
    public var notes: String?
    public var scriptName: String
    public var durationMs: Int

    public init(sessionDir: String, condition: String, device: String, recordedAt: Date,
                notes: String?, scriptName: String, durationMs: Int) {
        self.sessionDir = sessionDir
        self.condition = condition
        self.device = device
        self.recordedAt = recordedAt
        self.notes = notes
        self.scriptName = scriptName
        self.durationMs = durationMs
    }
}

public struct SweepCell: Codable, Equatable, Sendable {
    public var vadMarginDb: Double
    public var userBandDb: Double
    public var attributionAccuracy: Double?
    public var uncertainFraction: Double?
}

/// analysis.json: one session's grade.
public struct Analysis: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var session: SessionInfo
    public var config: ClassifierConfig
    public var usesDefaultConfig: Bool
    public var score: ScoreResult
    public var sweep: [SweepCell]?

    public init(session: SessionInfo, config: ClassifierConfig, score: ScoreResult, sweep: [SweepCell]?) {
        self.session = session
        self.config = config
        self.usesDefaultConfig = config.isDefault
        self.score = score
        self.sweep = sweep
    }
}
