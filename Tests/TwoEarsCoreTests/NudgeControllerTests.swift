import XCTest
@testable import TwoEarsCore

final class NudgeControllerTests: XCTestCase {
    private func listen() -> NudgeController {
        NudgeController(config: NudgeConfig(threshold: 0.40))
    }

    func testCrossingThresholdTapsOnce() {
        var c = listen()
        XCTAssertNil(c.update(share: .value(0.30), at: 0))
        XCTAssertEqual(c.update(share: .value(0.41), at: 10), .single)
        XCTAssertEqual(c.state, .crossed)
        XCTAssertNil(c.update(share: .value(0.45), at: 11))
    }

    func testExactThresholdDoesNotTap() {
        var c = listen()
        XCTAssertNil(c.update(share: .value(0.40), at: 0))
        XCTAssertEqual(c.state, .below)
    }

    func testUncertainNeverChangesState() {
        var c = listen()
        XCTAssertNil(c.update(share: .uncertain, at: 0))
        XCTAssertEqual(c.update(share: .value(0.5), at: 1), .single)
        XCTAssertNil(c.update(share: .uncertain, at: 2))
        XCTAssertEqual(c.state, .crossed)
        XCTAssertNil(c.update(share: .uncertain, at: 100))
        XCTAssertEqual(c.state, .crossed)
    }

    func testEscalatesOnceAfterSixtySeconds() {
        var c = listen()
        XCTAssertEqual(c.update(share: .value(0.5), at: 0), .single)
        XCTAssertNil(c.update(share: .value(0.5), at: 59.9))
        XCTAssertEqual(c.update(share: .value(0.5), at: 60), .double)
        XCTAssertEqual(c.state, .escalated)
        XCTAssertNil(c.update(share: .value(0.6), at: 200))
    }

    func testHysteresisReturnsToBelow() {
        var c = listen()
        _ = c.update(share: .value(0.5), at: 0)
        XCTAssertNil(c.update(share: .value(0.36), at: 5))
        XCTAssertEqual(c.state, .crossed, "0.36 is inside the 5-point hysteresis band")
        XCTAssertNil(c.update(share: .value(0.34), at: 6))
        XCTAssertEqual(c.state, .below)
    }

    func testCooldownSuppressesSecondSingleTap() {
        var c = listen()
        XCTAssertEqual(c.update(share: .value(0.5), at: 0), .single)
        _ = c.update(share: .value(0.30), at: 10)
        XCTAssertEqual(c.state, .below)
        XCTAssertNil(c.update(share: .value(0.5), at: 100), "re-crossed inside the 120 s cooldown")
        XCTAssertEqual(c.state, .crossed, "state still tracks the crossing so escalation can fire")
        _ = c.update(share: .value(0.30), at: 110)
        XCTAssertEqual(c.update(share: .value(0.5), at: 121), .single)
    }

    func testEscalationCanFireDuringCooldownCrossing() {
        var c = listen()
        _ = c.update(share: .value(0.5), at: 0)
        _ = c.update(share: .value(0.30), at: 10)
        XCTAssertNil(c.update(share: .value(0.5), at: 20))
        XCTAssertEqual(c.update(share: .value(0.5), at: 80), .double)
    }

    func testPresentingDisablesEverything() {
        var c = NudgeController(config: NudgeConfig(threshold: nil))
        XCTAssertNil(c.update(share: .value(0.99), at: 0))
        XCTAssertNil(c.update(share: .value(0.99), at: 500))
        XCTAssertFalse(c.isOverThreshold)
    }
}
