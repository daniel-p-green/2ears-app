import XCTest
@testable import TwoEarsCore

final class ListeningScoreTests: XCTestCase {
    private func score(share: Double?, target: Double? = 0.40, stretch: Double = 30,
                       nudges: Int = 0, judged: Int = 0, followed: Int = 0) -> ListeningScore? {
        ListeningScore.compute(talkShare: share, targetShare: target, longestStretchSeconds: stretch,
                               nudgeCount: nudges, nudgesJudged: judged, nudgesFollowed: followed)
    }

    func testPerfectSessionIsOneHundred() {
        let s = try! XCTUnwrap(score(share: 0.30))
        XCTAssertEqual(s.value, 100)
        XCTAssertEqual(s.band, .excellent)
        XCTAssertEqual(s.shareComponent, 60)
        XCTAssertEqual(s.stretchComponent, 20)
        XCTAssertEqual(s.responseComponent, 20)
    }

    func testAtTargetStillEarnsFullShareCredit() {
        XCTAssertEqual(score(share: 0.40)?.shareComponent, 60)
    }

    func testShareFadesLinearlyPastTarget() {
        XCTAssertEqual(score(share: 0.575)?.shareComponent, 30, "halfway through the 35-point fade")
        XCTAssertEqual(score(share: 0.75)?.shareComponent, 0)
        XCTAssertEqual(score(share: 0.95)?.shareComponent, 0)
    }

    func testStretchFadesAfterAMinute() {
        XCTAssertEqual(score(share: 0.3, stretch: 60)?.stretchComponent, 20)
        XCTAssertEqual(score(share: 0.3, stretch: 120)?.stretchComponent, 10)
        XCTAssertEqual(score(share: 0.3, stretch: 180)?.stretchComponent, 0)
    }

    func testResponseCredit() {
        XCTAssertEqual(score(share: 0.3, nudges: 0)?.responseComponent, 20)
        XCTAssertEqual(score(share: 0.3, nudges: 1, judged: 0)?.responseComponent, 10, "unjudged is half credit")
        XCTAssertEqual(score(share: 0.3, nudges: 2, judged: 2, followed: 1)?.responseComponent, 10)
        XCTAssertEqual(score(share: 0.3, nudges: 2, judged: 2, followed: 0)?.responseComponent, 0)
    }

    func testBands() {
        XCTAssertEqual(ListeningScore.Band(value: 100), .excellent)
        XCTAssertEqual(ListeningScore.Band(value: 90), .excellent)
        XCTAssertEqual(ListeningScore.Band(value: 89), .good)
        XCTAssertEqual(ListeningScore.Band(value: 75), .good)
        XCTAssertEqual(ListeningScore.Band(value: 60), .ok)
        XCTAssertEqual(ListeningScore.Band(value: 40), .low)
        XCTAssertEqual(ListeningScore.Band(value: 39), .veryLow)
    }

    func testNoScoreWithoutTargetOrShare() {
        XCTAssertNil(score(share: 0.3, target: nil))
        XCTAssertNil(score(share: nil))
    }

    func testTypicalOverTalkerSession() {
        // 77% talking against a 40% target, one 25 s stretch, one nudge not yet judged.
        let s = try! XCTUnwrap(score(share: 0.77, stretch: 25, nudges: 1))
        XCTAssertEqual(s.shareComponent, 0)
        XCTAssertEqual(s.value, 30)
        XCTAssertEqual(s.band, .veryLow)
    }
}
