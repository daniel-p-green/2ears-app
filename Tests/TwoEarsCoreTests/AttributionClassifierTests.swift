import XCTest
@testable import TwoEarsCore

final class AttributionClassifierTests: XCTestCase {
    private func classify(_ aboveFloor: Double) -> Attribution {
        AttributionClassifier.classify(levelDb: -60 + aboveFloor, noiseFloorDb: -60, config: .default)
    }

    func testSpecExamples() {
        XCTAssertEqual(classify(12), .room)
        XCTAssertEqual(classify(16), .uncertain)
        XCTAssertEqual(classify(20), .user)
    }

    func testUpperEdge() {
        XCTAssertEqual(classify(19), .user)
        XCTAssertEqual(classify(18.99), .uncertain)
    }

    func testLowerEdge() {
        XCTAssertEqual(classify(13), .room)
        XCTAssertEqual(classify(13.01), .uncertain)
    }

    func testCustomBands() {
        var c = ClassifierConfig.default
        c.userBandDb = 10
        c.uncertainMarginDb = 1
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -49, noiseFloorDb: -60, config: c), .user)
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -50, noiseFloorDb: -60, config: c), .uncertain)
        XCTAssertEqual(AttributionClassifier.classify(levelDb: -51, noiseFloorDb: -60, config: c), .room)
    }
}
