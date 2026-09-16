import XCTest
@testable import TwoEarsCore

final class SessionAggregatorTests: XCTestCase {
    private let config = ClassifierConfig.default

    private func window(_ index: Int, _ attribution: Attribution?) -> WindowStat {
        WindowStat(index: index, startMs: index * 100, levelDb: -30, noiseFloorDb: -60, zcr: 0.05,
                   voiced: attribution != nil, attribution: attribution)
    }

    private func windows(_ pattern: [(Attribution?, Int)]) -> [WindowStat] {
        var out: [WindowStat] = []
        for (attribution, count) in pattern {
            for _ in 0..<count { out.append(window(out.count, attribution)) }
        }
        return out
    }

    func testLongestStretchToleratesShortGaps() {
        var a = SessionAggregator()
        a.record(windows([(.user, 20), (nil, 10), (.user, 20), (nil, 11), (.user, 5)]), config: config)
        XCTAssertEqual(a.longestUserStretchSeconds, 5.0, accuracy: 1e-9,
                       "20 + 10 gap + 20 windows = 5 s; an 11-window gap breaks the stretch")
    }

    func testShortRoomInterjectionDoesNotBreakStretch() {
        var a = SessionAggregator()
        a.record(windows([(.user, 10), (.room, 3), (.user, 10)]), config: config)
        XCTAssertEqual(a.longestUserStretchSeconds, 2.3, accuracy: 1e-9)
    }

    func testUncertainFractionAndLastVoiced() {
        var a = SessionAggregator()
        a.record(windows([(nil, 10), (.user, 5), (.uncertain, 5), (nil, 30)]), config: config)
        XCTAssertEqual(a.totalWindows, 50)
        XCTAssertEqual(a.uncertainFraction, 0.1, accuracy: 1e-9)
        XCTAssertEqual(a.lastVoicedAt, 1.9, accuracy: 1e-9)
    }

    func testPerMinuteSamplingFillsMissedMinutes() {
        var a = SessionAggregator()
        a.tick(elapsed: 30, share: .value(0.5))
        XCTAssertEqual(a.perMinuteShare.count, 0)
        a.tick(elapsed: 61, share: .value(0.5))
        XCTAssertEqual(a.perMinuteShare, [0.5])
        a.tick(elapsed: 185, share: .uncertain)
        XCTAssertEqual(a.perMinuteShare, [0.5, nil, nil])
    }

    func testNudgeFollowedWhenShareDropsWithinTwoMinutes() {
        var a = SessionAggregator()
        a.recordNudge(at: 10, share: .value(0.60))
        a.tick(elapsed: 100, share: .value(0.50))
        XCTAssertEqual(a.nudgesFollowed, 0, "not due yet")
        a.tick(elapsed: 130, share: .value(0.54))
        XCTAssertEqual(a.nudgeCount, 1)
        XCTAssertEqual(a.nudgesFollowed, 1)
    }

    func testNudgeNotFollowedWhenShareStaysUp() {
        var a = SessionAggregator()
        a.recordNudge(at: 10, share: .value(0.60))
        a.tick(elapsed: 131, share: .value(0.58))
        XCTAssertEqual(a.nudgesFollowed, 0)
    }

    func testNudgeDuringUncertainIsCountedButNotJudged() {
        var a = SessionAggregator()
        a.recordNudge(at: 10, share: .uncertain)
        a.finish(share: .value(0.1))
        XCTAssertEqual(a.nudgeCount, 1)
        XCTAssertEqual(a.nudgesFollowed, 0)
    }

    func testFinishJudgesOutstandingNudges() {
        var a = SessionAggregator()
        a.recordNudge(at: 10, share: .value(0.60))
        a.recordNudge(at: 20, share: .value(0.70))
        a.finish(share: .value(0.30))
        XCTAssertEqual(a.nudgesFollowed, 2)
    }
}
