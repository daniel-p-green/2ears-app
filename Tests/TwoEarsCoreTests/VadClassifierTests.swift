import XCTest
@testable import TwoEarsCore

final class VadClassifierTests: XCTestCase {
    private func window(_ index: Int, level: Double, floor: Double = -60, zcr: Double = 0.05) -> WindowStat {
        WindowStat(index: index, startMs: index * 100, levelDb: level, noiseFloorDb: floor,
                   zcr: zcr, voiced: false, attribution: nil)
    }

    /// Feeds `levels` in order, then finish(), returning every emitted window.
    private func run(_ levels: [Double], zcr: Double = 0.05) -> [WindowStat] {
        var vad = VadClassifier(config: .default)
        var out: [WindowStat] = []
        for (i, level) in levels.enumerated() {
            out += vad.process(window(i, level: level, zcr: zcr))
        }
        out += vad.finish()
        return out
    }

    func testBelowMarginIsUnvoiced() {
        let out = run(Array(repeating: -52.1, count: 10))   // floor -60 + 7.9
        XCTAssertEqual(out.count, 10)
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testAboveMarginLongRunIsVoiced() {
        let out = run(Array(repeating: -51.9, count: 10))   // floor -60 + 8.1
        XCTAssertEqual(out.count, 10)
        XCTAssertTrue(out.allSatisfy { $0.voiced })
    }

    func testOutOfBandZcrIsUnvoiced() {
        let out = run(Array(repeating: -20, count: 10), zcr: 0.5)
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testSevenWindowBurstIsRejected() {
        let levels = Array(repeating: -20.0, count: 7) + Array(repeating: -70.0, count: 3)
        let out = run(levels)
        XCTAssertEqual(out.map(\.index), Array(0..<10))
        XCTAssertTrue(out.allSatisfy { !$0.voiced })
    }

    func testEightWindowRunIsKept() {
        let levels = Array(repeating: -20.0, count: 8) + Array(repeating: -70.0, count: 3)
        let out = run(levels)
        XCTAssertEqual(out.map(\.index), Array(0..<11))
        XCTAssertEqual(out.prefix(8).map(\.voiced), Array(repeating: true, count: 8))
        XCTAssertEqual(out.suffix(3).map(\.voiced), Array(repeating: false, count: 3))
    }

    func testEmissionIsDelayedUntilRunConfirms() {
        var vad = VadClassifier(config: .default)
        var emitted: [WindowStat] = []
        for i in 0..<7 { emitted += vad.process(window(i, level: -20)) }
        XCTAssertEqual(emitted.count, 0)
        emitted += vad.process(window(7, level: -20))
        XCTAssertEqual(emitted.count, 8)
        emitted += vad.process(window(8, level: -20))
        XCTAssertEqual(emitted.count, 9)
    }

    func testFinishResolvesPendingRunAsUnvoiced() {
        var vad = VadClassifier(config: .default)
        var emitted: [WindowStat] = []
        for i in 0..<5 { emitted += vad.process(window(i, level: -20)) }
        XCTAssertEqual(emitted.count, 0)
        emitted += vad.finish()
        XCTAssertEqual(emitted.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertTrue(emitted.allSatisfy { !$0.voiced })
    }
}
