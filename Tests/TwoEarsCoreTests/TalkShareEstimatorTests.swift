import XCTest
@testable import TwoEarsCore

final class TalkShareEstimatorTests: XCTestCase {
    private func feed(_ estimator: inout TalkShareEstimator, _ attribution: Attribution?, count: Int) {
        for _ in 0..<count {
            estimator.push(WindowStat(index: 0, startMs: 0, levelDb: 0, noiseFloorDb: 0, zcr: 0,
                                      voiced: attribution != nil, attribution: attribution))
        }
    }

    func testEmptyIsUncertain() {
        let e = TalkShareEstimator(config: .default)
        XCTAssertEqual(e.share, .uncertain)
    }

    func testThirtySevenSecondsVoicedIsUncertain() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 370)   // 37.0s, just under the 37.5s minimum-evidence gate
        XCTAssertEqual(e.share, .uncertain)
    }

    func testThirtyEightSecondsVoicedGivesValue() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 380)   // 38.0s, just over the 37.5s gate
        XCTAssertEqual(e.share, .value(1.0))
    }

    func testThirtyOnePercentUncertainIsUncertain() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 690)
        feed(&e, .uncertain, count: 310)
        XCTAssertEqual(e.share, .uncertain)
    }

    func testThirtyPercentUncertainStillReports() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 700)
        feed(&e, .uncertain, count: 300)
        XCTAssertEqual(e.share, .value(1.0))
    }

    func testEqualUserAndRoomIsHalf() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 600)
        feed(&e, .room, count: 600)
        XCTAssertEqual(e.share, .value(0.5))
    }

    func testUnvoicedWindowsDoNotCount() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .user, count: 200)
        feed(&e, nil, count: 500)
        feed(&e, .room, count: 200)
        XCTAssertEqual(e.share, .value(0.5))
    }

    func testTrailingWindowForgetsOldWindows() {
        var e = TalkShareEstimator(config: .default)
        feed(&e, .room, count: 3000)   // fills the 300s/3000-window capacity once
        feed(&e, .user, count: 3000)   // then fully displaces it
        XCTAssertEqual(e.share, .value(1.0))
    }
}
