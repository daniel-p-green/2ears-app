import AVFAudio
import Foundation

/// Live wrist microphone through AVAudioEngine, converted to 16 kHz mono in memory.
/// Buffers are consumed and released; nothing is written anywhere.
final class MicrophoneAudioSource: AudioSource {
    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000,
                                             channels: 1, interleaved: false)!

    func start(handler: @escaping @Sendable ([Float]) -> Void) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)

        let input = engine.inputNode
        let hardware = input.outputFormat(forBus: 0)
        guard hardware.channelCount > 0,
              let converter = AVAudioConverter(from: hardware, to: targetFormat)
        else { throw AudioSourceError.unsupportedFormat }
        let target = targetFormat

        input.installTap(onBus: 0, bufferSize: 2048, format: hardware) { buffer, _ in
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
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
            handler(Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength))))
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
