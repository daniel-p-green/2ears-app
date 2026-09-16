import Foundation
import TwoEarsCore

public enum Prediction: String, Codable, Sendable, CaseIterable {
    case user, room, uncertain, unvoiced

    public init(_ w: WindowStat) {
        guard w.voiced, let a = w.attribution else { self = .unvoiced; return }
        switch a {
        case .user: self = .user
        case .room: self = .room
        case .uncertain: self = .uncertain
        }
    }
}

public struct BlockScore: Codable, Equatable, Sendable {
    public var label: TurnLabel
    public var startMs: Int
    public var endMs: Int
    public var scoredWindows: Int
    /// Attribution accuracy; nil for blocks that are not you/partner or had no voiced predictions.
    public var accuracy: Double?
    public var meanLevelDb: Double
    public var meanFloorDb: Double
}

public struct ScoreResult: Codable, Equatable, Sendable {
    public var scoredWindows = 0
    public var marginWindows = 0
    public var attributionWindowCount = 0
    public var attributionAccuracy: Double?
    public var uncertainFraction: Double?
    public var vadRecall: Double?
    public var vadPrecision: Double?
    public var bothUncertainFraction: Double?
    /// truth ("you"/"partner"/"silence") -> prediction -> count
    public var confusion: [String: [String: Int]] = [:]
    public var perBlock: [BlockScore] = []
    public var worstBlocks: [BlockScore] = []
    public var sharePointCount = 0
    public var shareMeanAbsErrorPoints: Double?
    public var shareUncertainFraction: Double?

    public init() {}
}

public enum Scorer {
    public static let marginMs = 500

    public struct Truth: Equatable {
        public var label: TurnLabel
        public var blockIndex: Int
        public var isMargin: Bool
    }

    /// nil when the time is absent (after endedEarlyAtMs or outside every block).
    public static func truth(atMs t: Int, labels: SessionLabels) -> Truth? {
        if let early = labels.endedEarlyAtMs, t >= early { return nil }
        guard let i = labels.blocks.firstIndex(where: { t >= $0.startMs && t < $0.endMs }) else { return nil }
        let b = labels.blocks[i]
        let isMargin = (t - b.startMs) < marginMs || (b.endMs - t) <= marginMs
        return Truth(label: b.label, blockIndex: i, isMargin: isMargin)
    }

    public static func score(windows: [WindowStat], labels: SessionLabels, config: ClassifierConfig) -> ScoreResult {
        var r = ScoreResult()
        var attrCorrect = 0, attrUncertain = 0
        var speechWindows = 0, speechVoiced = 0
        var voicedPreds = 0, voicedPredsNotSilence = 0
        var bothVoiced = 0, bothUncertain = 0
        struct BlockAcc { var correct = 0, attributed = 0, scored = 0; var levelSum = 0.0, floorSum = 0.0 }
        var blockAcc = [BlockAcc](repeating: BlockAcc(), count: labels.blocks.count)
        var blockSeen = [Bool](repeating: false, count: labels.blocks.count)

        for w in windows {
            guard let t = truth(atMs: w.startMs, labels: labels) else { continue }
            blockSeen[t.blockIndex] = true
            if t.isMargin { r.marginWindows += 1; continue }
            r.scoredWindows += 1
            let pred = Prediction(w)
            blockAcc[t.blockIndex].scored += 1
            blockAcc[t.blockIndex].levelSum += w.levelDb
            blockAcc[t.blockIndex].floorSum += w.noiseFloorDb

            switch t.label {
            case .you, .partner:
                r.confusion[t.label.rawValue, default: [:]][pred.rawValue, default: 0] += 1
                speechWindows += 1
                if w.voiced {
                    speechVoiced += 1
                    voicedPreds += 1
                    voicedPredsNotSilence += 1
                    r.attributionWindowCount += 1
                    blockAcc[t.blockIndex].attributed += 1
                    let correct = (t.label == .you && pred == .user) || (t.label == .partner && pred == .room)
                    if correct { attrCorrect += 1; blockAcc[t.blockIndex].correct += 1 }
                    if pred == .uncertain { attrUncertain += 1 }
                }
            case .silence:
                r.confusion["silence", default: [:]][pred.rawValue, default: 0] += 1
                if w.voiced { voicedPreds += 1 }
            case .both:
                if w.voiced {
                    voicedPreds += 1
                    voicedPredsNotSilence += 1
                    bothVoiced += 1
                    if pred == .uncertain { bothUncertain += 1 }
                }
            }
        }

        func ratio(_ n: Int, _ d: Int) -> Double? { d > 0 ? Double(n) / Double(d) : nil }
        r.attributionAccuracy = ratio(attrCorrect, r.attributionWindowCount)
        r.uncertainFraction = ratio(attrUncertain, r.attributionWindowCount)
        r.vadRecall = ratio(speechVoiced, speechWindows)
        r.vadPrecision = ratio(voicedPredsNotSilence, voicedPreds)
        r.bothUncertainFraction = ratio(bothUncertain, bothVoiced)

        for (i, b) in labels.blocks.enumerated() where blockSeen[i] && (b.label == .you || b.label == .partner) {
            let a = blockAcc[i]
            r.perBlock.append(BlockScore(
                label: b.label, startMs: b.startMs, endMs: b.endMs, scoredWindows: a.scored,
                accuracy: ratio(a.correct, a.attributed),
                meanLevelDb: a.scored > 0 ? a.levelSum / Double(a.scored) : 0,
                meanFloorDb: a.scored > 0 ? a.floorSum / Double(a.scored) : 0))
        }
        r.worstBlocks = Array(r.perBlock.sorted { ($0.accuracy ?? -1) < ($1.accuracy ?? -1) }.prefix(3))

        scoreShare(windows: windows, labels: labels, config: config, into: &r)
        return r
    }

    private static func scoreShare(windows: [WindowStat], labels: SessionLabels,
                                   config: ClassifierConfig, into r: inout ScoreResult) {
        var estimator = TalkShareEstimator(config: config)
        var cursor = 0
        var absErrorSum = 0.0, errorCount = 0, uncertainCount = 0
        let spanMs = Int(config.shareWindowSec * 1000)

        for block in labels.blocks {
            if let early = labels.endedEarlyAtMs, block.startMs >= early { break }
            let end = min(block.endMs, labels.endedEarlyAtMs ?? Int.max)
            while cursor < windows.count, windows[cursor].startMs < end {
                estimator.push(windows[cursor])
                cursor += 1
            }
            guard let trueShare = trueShare(endingAtMs: end, spanMs: spanMs, labels: labels) else { continue }
            r.sharePointCount += 1
            switch estimator.share {
            case .uncertain:
                uncertainCount += 1
            case .value(let v):
                absErrorSum += abs(v - trueShare) * 100
                errorCount += 1
            }
        }
        r.shareMeanAbsErrorPoints = errorCount > 0 ? absErrorSum / Double(errorCount) : nil
        r.shareUncertainFraction = r.sharePointCount > 0 ? Double(uncertainCount) / Double(r.sharePointCount) : nil
    }

    /// True wearer share over [end - span, end) from labels; nil if no voiced time in range.
    static func trueShare(endingAtMs end: Int, spanMs: Int, labels: SessionLabels) -> Double? {
        let start = end - spanMs
        var user = 0, room = 0
        for b in labels.blocks {
            let overlap = max(0, min(b.endMs, end) - max(b.startMs, start))
            guard overlap > 0 else { continue }
            switch b.label {
            case .you: user += overlap
            case .partner: room += overlap
            case .both: user += overlap; room += overlap
            case .silence: break
            }
        }
        return user + room > 0 ? Double(user) / Double(user + room) : nil
    }
}
