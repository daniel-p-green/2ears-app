import XCTest
@testable import TwoEarsCore

final class ClassifierConfigTests: XCTestCase {
    func testDefaultsMatchSpec() {
        let c = ClassifierConfig.default
        XCTAssertEqual(c.sampleRate, 16000)
        XCTAssertEqual(c.windowMs, 100)
        XCTAssertEqual(c.floorTrailingSec, 10)
        XCTAssertEqual(c.floorPercentile, 0.10)
        XCTAssertEqual(c.vadMarginDb, 8)
        XCTAssertEqual(c.zcrMin, 0.01)
        XCTAssertEqual(c.zcrMax, 0.20)
        XCTAssertEqual(c.minBurstMs, 800)
        XCTAssertEqual(c.userBandDb, 16)
        XCTAssertEqual(c.uncertainMarginDb, 3)
        XCTAssertEqual(c.shareWindowSec, 120)
        XCTAssertEqual(c.minVoicedSec, 15)
        XCTAssertEqual(c.maxUncertainFraction, 0.30)
    }

    func testDerivedCounts() {
        let c = ClassifierConfig.default
        XCTAssertEqual(c.samplesPerWindow, 1600)
        XCTAssertEqual(c.floorWindowCount, 100)
        XCTAssertEqual(c.minBurstWindows, 8)
        XCTAssertEqual(c.shareWindowCount, 1200)
    }

    func testPartialJsonOverridesOnlyNamedKeys() throws {
        let json = #"{"vadMarginDb": 10, "userBandDb": 12}"#.data(using: .utf8)!
        let c = try JSONDecoder().decode(ClassifierConfig.self, from: json)
        XCTAssertEqual(c.vadMarginDb, 10)
        XCTAssertEqual(c.userBandDb, 12)
        XCTAssertEqual(c.minBurstMs, 800)
        XCTAssertFalse(c.isDefault)
        XCTAssertTrue(ClassifierConfig.default.isDefault)
    }

    func testRoundTripsThroughJson() throws {
        var c = ClassifierConfig.default
        c.zcrMax = 0.25
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(ClassifierConfig.self, from: data)
        XCTAssertEqual(back, c)
    }
}
