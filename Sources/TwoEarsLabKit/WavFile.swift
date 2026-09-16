import Foundation

public enum WavFileError: Error, Equatable, CustomStringConvertible {
    case notRiff
    case unsupportedFormat(String)
    case truncated

    public var description: String {
        switch self {
        case .notRiff: return "not a RIFF/WAVE file"
        case .unsupportedFormat(let s): return "unsupported WAV format: \(s)"
        case .truncated: return "WAV file is truncated"
        }
    }
}

/// Minimal PCM16 little-endian WAV I/O. Writes mono; reads any channel count and averages to mono.
public enum WavFile {
    public static func write(samples: [Float], sampleRate: Int, to url: URL) throws {
        let dataBytes = samples.count * 2
        var data = Data(capacity: 44 + dataBytes)
        func append<T: FixedWidthInteger>(_ v: T) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataBytes))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))                       // PCM
        append(UInt16(1))                       // channels
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))          // byte rate
        append(UInt16(2))                       // block align
        append(UInt16(16))                      // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(UInt32(dataBytes))
        for s in samples {
            let clamped = max(-1, min(1, s))
            append(Int16((clamped * 32767).rounded()))
        }
        try data.write(to: url)
    }

    public static func read(_ url: URL) throws -> (sampleRate: Int, samples: [Float]) {
        let bytes = [UInt8](try Data(contentsOf: url))
        guard bytes.count >= 12,
              String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE"
        else { throw WavFileError.notRiff }

        func u16(_ at: Int) -> Int { Int(bytes[at]) | Int(bytes[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }

        var offset = 12
        var format = 0, channels = 0, sampleRate = 0, bits = 0
        var dataRange: Range<Int>?
        while offset + 8 <= bytes.count {
            let id = String(decoding: bytes[offset..<offset + 4], as: UTF8.self)
            let size = u32(offset + 4)
            let body = offset + 8
            if id == "fmt " {
                guard body + 16 <= bytes.count else { throw WavFileError.truncated }
                format = u16(body); channels = u16(body + 2); sampleRate = u32(body + 4); bits = u16(body + 14)
            } else if id == "data" {
                guard body + size <= bytes.count else { throw WavFileError.truncated }
                dataRange = body..<(body + size)
            }
            offset = body + size + (size & 1)
        }
        guard format == 1, bits == 16 else {
            throw WavFileError.unsupportedFormat("format \(format), \(bits)-bit; need PCM 16-bit")
        }
        guard channels >= 1, let range = dataRange else { throw WavFileError.truncated }

        let frameCount = range.count / (2 * channels)
        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        var at = range.lowerBound
        for _ in 0..<frameCount {
            var acc: Float = 0
            for _ in 0..<channels {
                let v = Int16(bitPattern: UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8)
                acc += Float(v) / 32768
                at += 2
            }
            samples.append(acc / Float(channels))
        }
        return (sampleRate, samples)
    }
}
