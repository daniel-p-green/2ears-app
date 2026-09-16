import AVFoundation
import CoreAudio
import Foundation

public enum CaptureError: Error, CustomStringConvertible {
    case permissionDenied
    case deviceSelectionFailed(OSStatus)
    case converterUnavailable(String)

    public var description: String {
        switch self {
        case .permissionDenied:
            return "microphone access denied. Allow your terminal app under System Settings > Privacy & Security > Microphone, then retry."
        case .deviceSelectionFailed(let s):
            return "could not select input device (OSStatus \(s))"
        case .converterUnavailable(let f):
            return "cannot convert input format to 16 kHz mono: \(f)"
        }
    }
}

/// Captures one input device through AVAudioEngine and accumulates 16 kHz mono Float32 samples in memory.
/// The whole session is held in RAM (about 12 MB for the default 190 s script) and returned by stop().
public final class AudioCapture {
    private let engine = AVAudioEngine()
    private let converter: AVAudioConverter
    private let targetFormat: AVAudioFormat
    private let lock = NSLock()
    private var samples: [Float] = []
    public let hardwareFormatDescription: String

    public init(device: InputDevice, sampleRate: Int) throws {
        let input = engine.inputNode
        guard let unit = input.audioUnit else { throw CaptureError.deviceSelectionFailed(-1) }
        var deviceID = device.id
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                          &deviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else { throw CaptureError.deviceSelectionFailed(status) }

        let hardware = input.outputFormat(forBus: 0)
        hardwareFormatDescription = "\(Int(hardware.sampleRate)) Hz, \(hardware.channelCount) ch"
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate),
                                         channels: 1, interleaved: false),
              hardware.channelCount > 0,
              let converter = AVAudioConverter(from: hardware, to: target)
        else { throw CaptureError.converterUnavailable(hardware.description) }
        self.targetFormat = target
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: hardware) { [weak self] buffer, _ in
            self?.consume(buffer)
        }
    }

    public func start() throws {
        engine.prepare()
        try engine.start()
    }

    /// Stops the engine and returns everything captured so far.
    public func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    public var capturedSampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channel = out.floatChannelData else { return }
        let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
    }

    /// Blocks on the system permission prompt when access is undetermined.
    public static func ensureMicrophoneAccess() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            if !granted { throw CaptureError.permissionDenied }
        default:
            throw CaptureError.permissionDenied
        }
    }
}
