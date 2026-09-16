import AVFAudio
import Foundation

enum MicrophonePermission {
    enum Failure: Error {
        case denied
    }

    static func request() async throws {
        #if targetEnvironment(simulator)
        return
        #else
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return
        case .denied:
            throw Failure.denied
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { throw Failure.denied }
        @unknown default:
            throw Failure.denied
        }
        #endif
    }
}
