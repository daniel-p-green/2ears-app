import XCTest
import TwoEarsCore
@testable import TwoEarsLabKit

final class ReporterTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    private func analysis(_ dir: String, condition: String, accuracy: Double, custom: Bool = false,
                          worst: [BlockScore] = []) -> Analysis {
        var config = ClassifierConfig.default
        if custom { config.userBandDb = 12 }
        var score = ScoreResult()
        score.attributionAccuracy = accuracy
        score.uncertainFraction = 0.1
        score.vadPrecision = 0.9
        score.vadRecall = 0.8
        score.shareMeanAbsErrorPoints = 4
        score.shareUncertainFraction = 0.2
        score.worstBlocks = worst
        let info = SessionInfo(sessionDir: dir, condition: condition, device: "mic",
                               recordedAt: Date(timeIntervalSince1970: 1_800_000_000), notes: nil,
                               scriptName: "default", durationMs: 190_000)
        return Analysis(session: info, config: config, score: score, sweep: nil)
    }

    func testGoWithThreeQuietSessionsAtGate() {
        let v = Reporter.verdict(for: [
            analysis("a", condition: "quiet", accuracy: 0.90),
            analysis("b", condition: "quiet", accuracy: 0.90),
            analysis("c", condition: "quiet", accuracy: 0.85),
            analysis("d", condition: "cafe", accuracy: 0.30),
        ])
        XCTAssertEqual(v.verdict, .go)
        XCTAssertEqual(v.quietSessionCount, 3)
        XCTAssertEqual(v.meanQuietAccuracy!, 0.8833, accuracy: 1e-3)
    }

    func testNoGoBelowGate() {
        let v = Reporter.verdict(for: (0..<3).map { analysis("s\($0)", condition: "quiet", accuracy: 0.80) })
        XCTAssertEqual(v.verdict, .noGo)
    }

    func testInsufficientWithTwoQuietSessions() {
        let v = Reporter.verdict(for: (0..<2).map { analysis("s\($0)", condition: "quiet", accuracy: 0.95) })
        XCTAssertEqual(v.verdict, .insufficientData)
    }

    func testCustomConfigSessionsAreExcludedFromVerdict() {
        let v = Reporter.verdict(for: [
            analysis("a", condition: "quiet", accuracy: 0.95),
            analysis("b", condition: "quiet", accuracy: 0.95),
            analysis("c", condition: "quiet", accuracy: 0.95, custom: true),
        ])
        XCTAssertEqual(v.verdict, .insufficientData)
        XCTAssertEqual(v.quietSessionCount, 2)
    }

    func testMarkdownContent() {
        let worst = [BlockScore(label: .partner, startMs: 25_000, endMs: 45_000, scoredWindows: 190,
                                accuracy: 0.4, meanLevelDb: -38.5, meanFloorDb: -45.2)]
        let md = Reporter.markdown(for: [
            analysis("a", condition: "quiet", accuracy: 0.95),
            analysis("b", condition: "quiet", accuracy: 0.95, custom: true),
            analysis("c", condition: "cafe", accuracy: 0.40, worst: worst),
        ])
        XCTAssertTrue(md.contains("INSUFFICIENT DATA"))
        XCTAssertTrue(md.contains("## quiet"))
        XCTAssertTrue(md.contains("## cafe"))
        XCTAssertTrue(md.contains("custom config"))
        XCTAssertTrue(md.contains("95.0%"))
        XCTAssertTrue(md.contains("## Failure modes"))
        XCTAssertTrue(md.contains("partner 25s-45s"))
        XCTAssertTrue(md.contains("-38.5"))
    }

    func testLoadFindsNestedAnalysesSortedByDate() throws {
        let a = analysis("x", condition: "quiet", accuracy: 0.9)
        var b = analysis("y", condition: "cafe", accuracy: 0.5)
        b.session.recordedAt = Date(timeIntervalSince1970: 1_700_000_000)
        for (name, value) in [("x", a), ("deeper/y", b)] {
            let dir = tmp.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try SessionFiles.encoder.encode(value).write(to: dir.appendingPathComponent(SessionFiles.analysisName))
        }
        let loaded = try Reporter.loadAnalyses(under: tmp)
        XCTAssertEqual(loaded.map(\.session.sessionDir), ["y", "x"])
    }

    func testWriteReportCreatesFile() throws {
        let dir = tmp.appendingPathComponent("s")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try SessionFiles.encoder.encode(analysis("s", condition: "quiet", accuracy: 0.9))
            .write(to: dir.appendingPathComponent(SessionFiles.analysisName))
        let out = tmp.appendingPathComponent("report.md")
        let v = try Reporter.writeReport(under: tmp, to: out)
        XCTAssertEqual(v.verdict, .insufficientData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))
    }
}
