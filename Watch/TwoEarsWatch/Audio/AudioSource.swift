import Foundation

enum AudioSourceError: Error {
    case unsupportedFormat
}

/// Delivers 16 kHz mono Float32 sample chunks from an arbitrary thread until stopped.
@MainActor
protocol AudioSource: AnyObject {
    func start(handler: @escaping @Sendable ([Float]) -> Void) throws
    func stop()
    /// False while the system has paused delivery (interruption, route change, suspension).
    var isRunning: Bool { get }
    /// Restart delivery after the system paused it. No-op when already running.
    func resume()
}

enum AudioSources {
    /// The simulator has no microphone, so it plays a scripted conversation instead.
    @MainActor
    static func make() -> AudioSource {
        #if targetEnvironment(simulator)
        SimulatedAudioSource()
        #else
        MicrophoneAudioSource()
        #endif
    }
}
