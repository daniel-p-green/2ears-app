import XCTest
@testable import TwoEarsCore

final class LevelMeterTests: XCTestCase {
    func testFullScaleSineIsMinusThreeDb() {
        let s = Signal.sine(hz: 200, amplitude: 1.0, count: 1600)
        XCTAssertEqual(LevelMeter.levelDb(s[...]), -3.01, accuracy: 0.05)
    }

    func testDbfsHelperProducesRequestedLevel() {
        let s = Signal.sine(hz: 200, dbfs: -40, count: 1600)
        XCTAssertEqual(LevelMeter.levelDb(s[...]), -40, accuracy: 0.05)
    }

    func testZeroBlockIsSilenceFloor() {
        XCTAssertEqual(LevelMeter.levelDb(Signal.silence(count: 1600)[...]), -120)
        XCTAssertEqual(LevelMeter.levelDb([][...]), -120)
    }

    func testZeroCrossingRateOfTone() {
        // 200 Hz at 16 kHz crosses zero 400 times per second = 0.025 per sample.
        let s = Signal.sine(hz: 200, amplitude: 0.5, count: 16000)
        XCTAssertEqual(LevelMeter.zeroCrossingRate(s[...]), 0.025, accuracy: 0.001)
    }

    func testZeroCrossingRateOfNoiseIsHigh() {
        let n = Signal.noise(dbfs: -20, count: 16000)
        XCTAssertGreaterThan(LevelMeter.zeroCrossingRate(n[...]), 0.4)
    }
}
