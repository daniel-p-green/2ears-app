import AVFAudio
import Foundation
import os

/// Live wrist microphone through AVAudioEngine, converted to 16 kHz mono in memory.
/// Buffers are consumed and released; nothing is written anywhere.
/// Pauses for phone calls and other interruptions, and can be resumed after any system stop.
final class MicrophoneAudioSource: AudioSource {
    private static let logger = Logger(subsystem: "com.danielpgreen.twoears", category: "audio")

    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000,
                                             channels: 1, interleaved: false)!
    private var observers: [NSObjectProtocol] = []
    private var isStarted = false

    var isRunning: Bool { isStarted && engine.isRunning }

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
        isStarted = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: audioSession, queue: .main
        ) { [weak self] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        })
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        })
    }

    func stop() {
        isStarted = false
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resume() {
        guard isStarted, !engine.isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            Self.logger.error("Could not resume the microphone: \(error.localizedDescription)")
        }
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            engine.pause()
        case .ended:
            let options = optionsRaw.map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            if options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }
}
