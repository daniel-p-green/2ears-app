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

    func testUncertainFractionLastVoicedAndPipelineTime() {
        var a = SessionAggregator()
        a.record(windows([(nil, 10), (.user, 5), (.uncertain, 5), (nil, 30)]), config: config)
        XCTAssertEqual(a.totalWindows, 50)
        XCTAssertEqual(a.uncertainFraction, 0.1, accuracy: 1e-9)
        XCTAssertEqual(a.lastVoicedAt, 1.9, accuracy: 1e-9)
        XCTAssertEqual(a.pipelineSeconds, 5.0, accuracy: 1e-9)
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

    func testFinishSamplesThePartialMinute() {
        var a = SessionAggregator()
        a.tick(elapsed: 61, share: .value(0.5))
        a.finish(elapsed: 90, share: .value(0.7))
        XCTAssertEqual(a.perMinuteShare, [0.5, 0.7])

        var short = SessionAggregator()
        short.finish(elapsed: 45, share: .value(0.3))
        XCTAssertEqual(short.perMinuteShare, [0.3], "sessions under a minute still get one point")
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
        a.finish(elapsed: 200, share: .value(0.1))
        XCTAssertEqual(a.nudgeCount, 1)
        XCTAssertEqual(a.nudgesFollowed, 0)
    }

    func testFinishJudgesNudgesWithAtLeastHalfTheirWindow() {
        var a = SessionAggregator()
        a.recordNudge(at: 10, share: .value(0.60))
        a.recordNudge(at: 40, share: .value(0.70))
        a.finish(elapsed: 100, share: .value(0.30))
        XCTAssertEqual(a.nudgesFollowed, 2, "due at 130 and 160, both within 60 s of the end")
    }

    func testFinishLeavesVeryRecentNudgesUnjudged() {
        var a = SessionAggregator()
        a.recordNudge(at: 95, share: .value(0.60))
        a.finish(elapsed: 100, share: .value(0.30))
        XCTAssertEqual(a.nudgeCount, 1)
        XCTAssertEqual(a.nudgesFollowed, 0, "5 s is not enough evidence of course-correction")
    }
}
