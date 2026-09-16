import XCTest
@testable import TwoEarsCore

final class PipelineTests: XCTestCase {
    /// 3 s room noise at -60, 3 s loud tone at -30 (wearer), 3 s quiet tone at -48 (room).
    private func threeSegmentSignal() -> [Float] {
        Signal.noise(dbfs: -60, count: 3 * 16000)
            + Signal.sine(hz: 200, dbfs: -30, count: 3 * 16000)
            + Signal.sine(hz: 200, dbfs: -48, count: 3 * 16000)
    }

    private func runAll(_ samples: [Float], chunk: Int) -> (windows: [WindowStat], share: TalkShare) {
        let p = Pipeline(config: .default)
        var out: [WindowStat] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + chunk)
            out += p.process(Array(samples[start..<end]))
            start = end
        }
        out += p.finish()
        return (out, p.currentShare)
    }

    func testAttributesSegmentsAsExpected() {
        let (w, _) = runAll(threeSegmentSignal(), chunk: 4096)
        XCTAssertEqual(w.count, 90)
        XCTAssertEqual(w.map(\.index), Array(0..<90))
        XCTAssertEqual(w[10].startMs, 1000)
        XCTAssertTrue(w[0..<30].allSatisfy { !$0.voiced && $0.attribution == nil })
        XCTAssertTrue(w[30..<60].allSatisfy { $0.voiced && $0.attribution == .user })
        XCTAssertTrue(w[60..<90].allSatisfy { $0.voiced && $0.attribution == .room })
    }

    func testChunkSizeDoesNotChangeOutput() {
        let s = threeSegmentSignal()
        XCTAssertEqual(runAll(s, chunk: 37).windows, runAll(s, chunk: 4096).windows)
    }

    func testFinishEmitsHeldWindowsAndDropsPartialWindow() {
        let s = Signal.noise(dbfs: -60, count: 2 * 16000)
            + Signal.sine(hz: 200, dbfs: -20, count: 5 * 1600 + 700)
        let p = Pipeline(config: .default)
        let before = p.process(s)
        XCTAssertEqual(before.count, 20)
        let held = p.finish()
        XCTAssertEqual(held.map(\.index), [20, 21, 22, 23, 24])
        XCTAssertTrue(held.allSatisfy { !$0.voiced })
        XCTAssertEqual(p.finish().count, 0)
    }

    func testCurrentShareMatchesStandaloneEstimator() {
        let (w, share) = runAll(threeSegmentSignal(), chunk: 1000)
        var e = TalkShareEstimator(config: .default)
        for window in w { e.push(window) }
        XCTAssertEqual(share, e.share)
        XCTAssertEqual(share, .uncertain)   // only 6 s voiced, under the 37.5 s gate
    }

    func testShareBecomesValueWithEnoughEvidence() {
        // Continuous tone for more than 10 s would drag the noise floor up to the tone level and
        // mute VAD, so both speech segments use the dipped pattern (see Signal.dippedTone).
        // 220 windows/segment * 0.9 voiced ≈ 198 voiced windows/segment = 39.6 s total, clearing
        // the 37.5 s minimum-evidence gate while keeping the 50/50 split for the 0.5 assertion.
        let s = Signal.noise(dbfs: -60, count: 3 * 16000)
            + Signal.dippedTone(dbfs: -30, noiseDb: -60, windows: 220)
            + Signal.dippedTone(dbfs: -48, noiseDb: -60, windows: 220)
        let (_, share) = runAll(s, chunk: 4096)
        guard case .value(let v) = share else { return XCTFail("expected a value, got \(share)") }
        XCTAssertEqual(v, 0.5, accuracy: 0.02)   // 198 user and 198 room voiced windows
    }
}
