import Foundation

/// Plays `SimulatedConversation` in real time for the simulator, which has no microphone.
final class SimulatedAudioSource: AudioSource {
    private var task: Task<Void, Never>?

    func start(handler: @escaping @Sendable ([Float]) -> Void) throws {
        task = Task.detached(priority: .userInitiated) {
            var window = 0
            var sampleIndex = 0
            var seed: UInt64 = 7
            let clock = ContinuousClock()
            let started = clock.now
            while !Task.isCancelled {
                let chunk = SimulatedConversation.chunk(window: window, sampleIndex: &sampleIndex, seed: &seed)
                handler(chunk)
                window += 1
                let next = started + .milliseconds(100 * window)
                try? await Task.sleep(until: next, clock: clock)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
