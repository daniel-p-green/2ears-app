import XCTest
@testable import TwoEarsLabKit

final class TurnScriptTests: XCTestCase {
    func testDefaultScriptTotalsOneNinetySeconds() {
        XCTAssertEqual(TurnScript.default.totalMs, 190_000)
        XCTAssertEqual(TurnScript.default.blocks.count, 13)
        XCTAssertEqual(TurnScript.default.name, "default")
    }

    func testTimelineIsContiguous() {
        let t = TurnScript.default.timeline()
        XCTAssertEqual(t.first?.startMs, 0)
        XCTAssertEqual(t.last?.endMs, 190_000)
        for (a, b) in zip(t, t.dropFirst()) { XCTAssertEqual(a.endMs, b.startMs) }
        XCTAssertEqual(t[1], LabelBlock(label: .you, startMs: 5000, endMs: 25_000))
    }

    func testDecodesJson() throws {
        let json = #"{"name":"tiny","blocks":[{"label":"you","seconds":1.5},{"label":"silence","seconds":2}]}"#
        let s = try TurnScript.decode(Data(json.utf8))
        XCTAssertEqual(s.totalMs, 3500)
        XCTAssertEqual(s.blocks[0].label, .you)
    }

    func testRejectsUnknownLabel() {
        let json = #"{"name":"bad","blocks":[{"label":"host","seconds":1}]}"#
        XCTAssertThrowsError(try TurnScript.decode(Data(json.utf8)))
    }

    func testRejectsEmptyAndNonPositive() {
        XCTAssertThrowsError(try TurnScript.decode(Data(#"{"name":"e","blocks":[]}"#.utf8)))
        XCTAssertThrowsError(try TurnScript.decode(Data(#"{"name":"z","blocks":[{"label":"you","seconds":0}]}"#.utf8)))
    }

    func testSessionLabelsRoundTrip() throws {
        let labels = SessionLabels(recordedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                   condition: "quiet", device: "Built-in Microphone", notes: "desk",
                                   sampleRate: 16000, scriptName: "default",
                                   blocks: TurnScript.default.timeline(), endedEarlyAtMs: 12_345)
        let data = try SessionFiles.encoder.encode(labels)
        let back = try SessionFiles.decoder.decode(SessionLabels.self, from: data)
        XCTAssertEqual(back, labels)
        XCTAssertEqual(back.version, 1)
    }

    func testDirectoryName() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15T08:00:00Z
        let name = SessionFiles.directoryName(recordedAt: date, condition: "cafe", timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(name, "20270115-080000-cafe")
    }
}
