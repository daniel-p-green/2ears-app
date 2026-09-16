import Foundation

public enum TurnLabel: String, Codable, Sendable, CaseIterable {
    case you, partner, both, silence
}

/// A labeled span in a session, in milliseconds from recording start.
public struct LabelBlock: Codable, Equatable, Sendable {
    public var label: TurnLabel
    public var startMs: Int
    public var endMs: Int

    public init(label: TurnLabel, startMs: Int, endMs: Int) {
        self.label = label
        self.startMs = startMs
        self.endMs = endMs
    }

    public var durationMs: Int { endMs - startMs }
}

public enum TurnScriptError: Error, CustomStringConvertible {
    case empty
    case nonPositiveDuration(index: Int)

    public var description: String {
        switch self {
        case .empty: return "script has no blocks"
        case .nonPositiveDuration(let i): return "block \(i) has a non-positive duration"
        }
    }
}

/// The prompt sequence shown during a recording. Labels derive from it.
public struct TurnScript: Codable, Equatable, Sendable {
    public struct Block: Codable, Equatable, Sendable {
        public var label: TurnLabel
        public var seconds: Double
        public init(_ label: TurnLabel, _ seconds: Double) {
            self.label = label
            self.seconds = seconds
        }
    }

    public var name: String
    public var blocks: [Block]

    public init(name: String, blocks: [Block]) {
        self.name = name
        self.blocks = blocks
    }

    public var totalMs: Int { blocks.reduce(0) { $0 + Int(($1.seconds * 1000).rounded()) } }

    public func validate() throws {
        guard !blocks.isEmpty else { throw TurnScriptError.empty }
        for (i, b) in blocks.enumerated() where b.seconds <= 0 {
            throw TurnScriptError.nonPositiveDuration(index: i)
        }
    }

    public func timeline() -> [LabelBlock] {
        var out: [LabelBlock] = []
        var cursor = 0
        for b in blocks {
            let end = cursor + Int((b.seconds * 1000).rounded())
            out.append(LabelBlock(label: b.label, startMs: cursor, endMs: end))
            cursor = end
        }
        return out
    }

    public static func decode(_ data: Data) throws -> TurnScript {
        let script = try JSONDecoder().decode(TurnScript.self, from: data)
        try script.validate()
        return script
    }

    public static func load(from url: URL) throws -> TurnScript {
        try decode(try Data(contentsOf: url))
    }

    public static let `default` = TurnScript(name: "default", blocks: [
        Block(.silence, 5), Block(.you, 20), Block(.partner, 20), Block(.you, 20), Block(.partner, 20),
        Block(.silence, 5), Block(.both, 10), Block(.partner, 20), Block(.you, 20),
        Block(.silence, 5), Block(.partner, 20), Block(.you, 20), Block(.silence, 5),
    ])
}
