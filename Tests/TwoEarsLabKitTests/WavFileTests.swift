import XCTest
@testable import TwoEarsLabKit

final class WavFileTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tmp)
    }

    func testRoundTripPreservesSamplesWithin16BitStep() throws {
        let url = tmp.appendingPathComponent("a.wav")
        let original: [Float] = (0..<16000).map { Float(sin(Double($0) / 25)) * 0.8 }
        try WavFile.write(samples: original, sampleRate: 16000, to: url)
        let back = try WavFile.read(url)
        XCTAssertEqual(back.sampleRate, 16000)
        XCTAssertEqual(back.samples.count, original.count)
        // Writer scales by 32767 and rounds; reader divides by 32768. Worst case is about 1.3 steps.
        for (a, b) in zip(original, back.samples) {
            XCTAssertEqual(a, b, accuracy: 1.5 / 32768 + 1e-6)
        }
    }

    func testWriteClampsOutOfRange() throws {
        let url = tmp.appendingPathComponent("c.wav")
        try WavFile.write(samples: [2.0, -2.0, 0], sampleRate: 16000, to: url)
        let back = try WavFile.read(url).samples
        XCTAssertEqual(back[0], 32767.0 / 32768, accuracy: 1e-6)
        XCTAssertEqual(back[1], -32767.0 / 32768, accuracy: 1e-6)
        XCTAssertEqual(back[2], 0)
    }

    func testHeaderSizesAreCorrect() throws {
        let url = tmp.appendingPathComponent("h.wav")
        try WavFile.write(samples: [Float](repeating: 0, count: 100), sampleRate: 16000, to: url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.count, 44 + 200)
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
    }

    func testRejectsNonWav() throws {
        let url = tmp.appendingPathComponent("x.wav")
        try Data("hello".utf8).write(to: url)
        XCTAssertThrowsError(try WavFile.read(url))
    }

    func testStereoIsAveragedToMono() throws {
        // Hand-build a 2-channel, 2-frame PCM16 file: frame 0 = (16384, 0), frame 1 = (-16384, -16384).
        var d = Data()
        func u16(_ v: UInt16) { d.append(UInt8(v & 0xff)); d.append(UInt8(v >> 8)) }
        func u32(_ v: UInt32) { u16(UInt16(v & 0xffff)); u16(UInt16(v >> 16)) }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + 8)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(2); u32(16000); u32(64000); u16(4); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(8)
        u16(16384); u16(0); u16(UInt16(bitPattern: -16384)); u16(UInt16(bitPattern: -16384))
        let url = tmp.appendingPathComponent("s.wav")
        try d.write(to: url)
        let back = try WavFile.read(url)
        XCTAssertEqual(back.samples.count, 2)
        XCTAssertEqual(back.samples[0], 0.25, accuracy: 1e-6)
        XCTAssertEqual(back.samples[1], -0.5, accuracy: 1e-6)
    }
}
