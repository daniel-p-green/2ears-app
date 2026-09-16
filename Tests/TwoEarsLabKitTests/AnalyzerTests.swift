import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class AnalyzerTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    func testFixtureScoresAboveGate() throws {
        let dir = tmp.appendingPathComponent("20270115-080000-quiet")
        try SyntheticSession.write(to: dir)
        let a = try Analyzer.analyze(sessionDir: dir)
        XCTAssertGreaterThan(a.score.attributionAccuracy ?? 0, 0.95)
        XCTAssertLessThan(a.score.shareMeanAbsErrorPoints ?? 100, 5)
        XCTAssertEqual(a.score.bothUncertainFraction ?? 0, 1.0, accuracy: 0.05)
        XCTAssertTrue(a.usesDefaultConfig)
        XCTAssertEqual(a.session.condition, "quiet")
        XCTAssertEqual(a.session.sessionDir, "20270115-080000-quiet")
        XCTAssertEqual(a.session.durationMs, 190_000)
        XCTAssertNil(a.sweep)

        let onDisk = try SessionFiles.decoder.decode(Analysis.self,
            from: Data(contentsOf: dir.appendingPathComponent(SessionFiles.analysisName)))
        XCTAssertEqual(onDisk, a)
    }

    func testCustomConfigIsFlagged() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        var c = ClassifierConfig.default
        c.userBandDb = 12
        let a = try Analyzer.analyze(sessionDir: dir, config: c)
        XCTAssertFalse(a.usesDefaultConfig)
        XCTAssertEqual(a.config.userBandDb, 12)
    }

    func testSweepProducesGridWithDefaultCellMatching() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        let a = try Analyzer.analyze(sessionDir: dir, sweep: true)
        let cells = try XCTUnwrap(a.sweep)
        XCTAssertEqual(cells.count, 24)
        let defaultCell = try XCTUnwrap(cells.first { $0.vadMarginDb == 8 && $0.userBandDb == 16 })
        XCTAssertEqual(defaultCell.attributionAccuracy, a.score.attributionAccuracy)
    }

    func testDumpWindowsCsv() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(to: dir)
        let csv = tmp.appendingPathComponent("w.csv")
        let a = try Analyzer.analyze(sessionDir: dir, dumpWindowsTo: csv)
        let text = try String(contentsOf: csv, encoding: .utf8)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.first, "index,startMs,levelDb,noiseFloorDb,zcr,voiced,attribution,truth")
        XCTAssertEqual(lines.count, 1 + a.session.durationMs / 100)
        XCTAssertTrue(lines[1].hasPrefix("0,0,"))
    }

    func testSampleRateMismatchThrows() throws {
        let dir = tmp.appendingPathComponent("s")
        try SyntheticSession.write(sampleRate: 44_100, to: dir)
        XCTAssertThrowsError(try Analyzer.analyze(sessionDir: dir)) { error in
            XCTAssertTrue("\(error)".contains("44100"))
        }
    }

    func testMissingFilesThrow() throws {
        let dir = tmp.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertThrowsError(try Analyzer.analyze(sessionDir: dir))
    }
}
