import Foundation

/// labels.json: the ground-truth timeline plus recording metadata.
public struct SessionLabels: Codable, Equatable, Sendable {
    public var version: Int = 1
    public var recordedAt: Date
    public var condition: String
    public var device: String
    public var notes: String?
    public var sampleRate: Int
    public var scriptName: String
    public var blocks: [LabelBlock]
    /// Set when recording stopped before the script finished. Windows at or after it are absent.
    public var endedEarlyAtMs: Int?

    public init(recordedAt: Date, condition: String, device: String, notes: String?,
                sampleRate: Int, scriptName: String, blocks: [LabelBlock], endedEarlyAtMs: Int?) {
        self.recordedAt = recordedAt
        self.condition = condition
        self.device = device
        self.notes = notes
        self.sampleRate = sampleRate
        self.scriptName = scriptName
        self.blocks = blocks
        self.endedEarlyAtMs = endedEarlyAtMs
    }

    public var scriptTotalMs: Int { blocks.last?.endMs ?? 0 }
}

/// File names and codecs shared by record, analyze, and report.
public enum SessionFiles {
    public static let audioName = "audio.wav"
    public static let labelsName = "labels.json"
    public static let analysisName = "analysis.json"

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    public static func directoryName(recordedAt: Date, condition: String, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyyMMdd-HHmmss"
        return "\(f.string(from: recordedAt))-\(condition)"
    }

    public static func readLabels(in dir: URL) throws -> SessionLabels {
        try decoder.decode(SessionLabels.self, from: Data(contentsOf: dir.appendingPathComponent(labelsName)))
    }

    public static func writeLabels(_ labels: SessionLabels, in dir: URL) throws {
        try encoder.encode(labels).write(to: dir.appendingPathComponent(labelsName))
    }
}
