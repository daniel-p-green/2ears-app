import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class ScorerTests: XCTestCase {
    enum Pred { case user, room, uncertain, unvoiced }

    private func window(_ startMs: Int, _ pred: Pred, level: Double = -30, floor: Double = -60) -> WindowStat {
        let attribution: Attribution?
        switch pred {
        case .user: attribution = .user
        case .room: attribution = .room
        case .uncertain: attribution = .uncertain
        case .unvoiced: attribution = nil
        }
        return WindowStat(index: startMs / 100, startMs: startMs, levelDb: level, noiseFloorDb: floor,
                          zcr: 0.05, voiced: pred != .unvoiced, attribution: attribution)
    }

    private func labels(_ blocks: [LabelBlock], endedEarlyAtMs: Int? = nil) -> SessionLabels {
        SessionLabels(recordedAt: Date(), condition: "quiet", device: "test", notes: nil,
                      sampleRate: 16000, scriptName: "test", blocks: blocks, endedEarlyAtMs: endedEarlyAtMs)
    }

    /// silence 0-2 s, you 2-6 s, partner 6-10 s, both 10-12 s, silence 12-14 s.
    private let fiveBlocks = [
        LabelBlock(label: .silence, startMs: 0, endMs: 2000),
        LabelBlock(label: .you, startMs: 2000, endMs: 6000),
        LabelBlock(label: .partner, startMs: 6000, endMs: 10_000),
        LabelBlock(label: .both, startMs: 10_000, endMs: 12_000),
        LabelBlock(label: .silence, startMs: 12_000, endMs: 14_000),
    ]

    /// Ideal predictions for fiveBlocks: unvoiced in silence, user in you, room in partner, uncertain in both.
    private func idealWindows() -> [WindowStat] {
        (0..<140).map { i in
            let ms = i * 100
            switch ms {
            case 0..<2000, 12_000..<14_000: return window(ms, .unvoiced)
            case 2000..<6000: return window(ms, .user)
            case 6000..<10_000: return window(ms, .room)
            default: return window(ms, .uncertain)
            }
        }
    }

    func testMarginRule() {
        let l = labels(fiveBlocks)
        XCTAssertEqual(Scorer.truth(atMs: 2000, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2400, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2500, labels: l)?.isMargin, false)
        XCTAssertEqual(Scorer.truth(atMs: 5400, labels: l)?.isMargin, false)
        XCTAssertEqual(Scorer.truth(atMs: 5500, labels: l)?.isMargin, true)
        XCTAssertEqual(Scorer.truth(atMs: 2500, labels: l)?.label, .you)
        XCTAssertNil(Scorer.truth(atMs: 14_000, labels: l))
        XCTAssertNil(Scorer.truth(atMs: 3000, labels: labels(fiveBlocks, endedEarlyAtMs: 3000)))
    }

    func testIdealPredictionsScorePerfectly() {
        let r = Scorer.score(windows: idealWindows(), labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.attributionAccuracy, 1.0)
        XCTAssertEqual(r.attributionWindowCount, 60)      // 30 scored windows per speech block
        XCTAssertEqual(r.uncertainFraction, 0.0)
        XCTAssertEqual(r.vadRecall, 1.0)
        XCTAssertEqual(r.vadPrecision, 1.0)
        XCTAssertEqual(r.bothUncertainFraction, 1.0)
        XCTAssertEqual(r.marginWindows, 5 * 10)           // 10 margin windows per block
        XCTAssertEqual(r.scoredWindows, 140 - 50)
        XCTAssertEqual(r.confusion["you"]?["user"], 30)
        XCTAssertEqual(r.confusion["partner"]?["room"], 30)
        XCTAssertEqual(r.confusion["silence"]?["unvoiced"], 20)
        XCTAssertEqual(r.perBlock.count, 2)
        XCTAssertEqual(r.worstBlocks.count, 2)
    }

    func testWrongAndUncertainPredictionsCountAgainstAccuracy() {
        var w = idealWindows()
        w[25] = window(2500, .room)          // you block, wrong
        w[26] = window(2600, .uncertain)     // you block, uncertain
        w[65] = window(6500, .user)          // partner block, wrong
        let r = Scorer.score(windows: w, labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.attributionAccuracy!, 57.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(r.uncertainFraction!, 1.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(r.confusion["you"]?["room"], 1)
        XCTAssertEqual(r.confusion["you"]?["uncertain"], 1)
        XCTAssertEqual(r.worstBlocks.first?.label, .you)
        XCTAssertEqual(r.worstBlocks.first!.accuracy!, 28.0 / 30.0, accuracy: 1e-9)
    }

    func testVadMetrics() {
        var w = idealWindows()
        w[30] = window(3000, .unvoiced)      // missed speech
        w[10] = window(1000, .room)          // voiced in silence
        let r = Scorer.score(windows: w, labels: labels(fiveBlocks), config: .default)
        XCTAssertEqual(r.vadRecall!, 59.0 / 60.0, accuracy: 1e-9)
        // voiced predictions: 59 speech + 10 both (scored, non-margin) + 1 silence = 70; not-silence = 69
        XCTAssertEqual(r.vadPrecision!, 69.0 / 70.0, accuracy: 1e-9)
        XCTAssertEqual(r.attributionWindowCount, 59)
    }

    func testEndedEarlyDropsLaterWindows() {
        let r = Scorer.score(windows: idealWindows(), labels: labels(fiveBlocks, endedEarlyAtMs: 6000), config: .default)
        XCTAssertEqual(r.attributionWindowCount, 30)
        XCTAssertEqual(r.perBlock.count, 1)
    }

    func testShareErrorIsZeroForPerfectEstimate() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 60_000),
                      LabelBlock(label: .partner, startMs: 60_000, endMs: 120_000)]
        let w = (0..<1200).map { i in window(i * 100, i < 600 ? .user : .room) }
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        XCTAssertEqual(r.sharePointCount, 2)
        XCTAssertEqual(r.shareMeanAbsErrorPoints!, 0, accuracy: 1e-9)
        XCTAssertEqual(r.shareUncertainFraction, 0)
    }

    func testShareErrorAveragesOverPoints() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 60_000),
                      LabelBlock(label: .partner, startMs: 60_000, endMs: 120_000)]
        let w = (0..<1200).map { i in window(i * 100, .user) }   // partner block misread as user
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        // point 1: est 1.0 vs true 1.0 = 0; point 2: est 1.0 vs true 0.5 = 50 points.
        XCTAssertEqual(r.shareMeanAbsErrorPoints!, 25, accuracy: 1e-9)
    }

    func testShareUncertainPointsAreCountedNotAveraged() {
        let blocks = [LabelBlock(label: .you, startMs: 0, endMs: 10_000)]
        let w = (0..<100).map { i in window(i * 100, .user) }   // 10 s voiced, under the 15 s gate
        let r = Scorer.score(windows: w, labels: labels(blocks), config: .default)
        XCTAssertEqual(r.sharePointCount, 1)
        XCTAssertNil(r.shareMeanAbsErrorPoints)
        XCTAssertEqual(r.shareUncertainFraction, 1.0)
    }
}
