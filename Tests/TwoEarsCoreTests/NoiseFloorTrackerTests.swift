import XCTest
@testable import TwoEarsCore

final class NoiseFloorTrackerTests: XCTestCase {
    func testEmptyReportsSilenceFloor() {
        let t = NoiseFloorTracker(config: .default)
        XCTAssertEqual(t.floorDb, -120)
    }

    func testWarmupReportsMinimumSeen() {
        var t = NoiseFloorTracker(config: .default)
        for level in [-40.0, -35, -50, -45] { t.push(level) }
        XCTAssertEqual(t.floorDb, -50)
    }

    func testTenthPercentileNearestRank() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<90 { t.push(-40) }
        for _ in 0..<10 { t.push(-60) }
        XCTAssertEqual(t.floorDb, -60)
    }

    func testNinePercentQuietWindowsDoNotSetFloor() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<91 { t.push(-40) }
        for _ in 0..<9 { t.push(-60) }
        XCTAssertEqual(t.floorDb, -40)
    }

    func testSingleLoudWindowDoesNotMoveFloor() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<100 { t.push(-50) }
        t.push(-10)
        XCTAssertEqual(t.floorDb, -50)
    }

    func testRingBufferForgetsOldLevels() {
        var t = NoiseFloorTracker(config: .default)
        for _ in 0..<100 { t.push(-70) }
        for _ in 0..<100 { t.push(-30) }
        XCTAssertEqual(t.floorDb, -30)
    }
}
