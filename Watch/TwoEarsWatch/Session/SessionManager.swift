import Foundation
import Observation
import TwoEarsCore
import WatchKit

/// Owns the session lifecycle and the app state machine: idle, active, ended.
/// Everything it publishes derives from window aggregates; no audio is retained.
@Observable
@MainActor
final class SessionManager {
    enum Phase: Equatable {
        case idle, active, ended
    }

    static let shared = SessionManager()

    private(set) var phase: Phase = .idle
    private(set) var intent: SessionIntent = .listen
    private(set) var share: TalkShare = .uncertain
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0
    private(set) var nudgeCount = 0
    private(set) var isOverThreshold = false
    private(set) var isLowBattery = false
    private(set) var lastSummary: SessionSummaryData?
    var isShowingStartError = false
    private(set) var startError = ""

    /// Seconds of silence before a session ends itself.
    var autoEndAfterSilence: TimeInterval = 180
    /// Battery fraction at which the controls page warns.
    var lowBatteryLevel: Float = 0.20
    /// Battery fraction at which the session ends itself to protect the day.
    var criticalBatteryLevel: Float = 0.05

    private let config = ClassifierConfig.default
    private var pipeline: Pipeline?
    private var source: AudioSource?
    private var nudges = NudgeController(config: NudgeConfig(threshold: nil))
    private var aggregator = SessionAggregator()
    private var runtime: RuntimeSession?
    private var ticker: Task<Void, Never>?
    private var isEnding = false

    init(sourceFactory: @escaping @MainActor () -> AudioSource = AudioSources.make) {
        self.sourceFactory = sourceFactory
    }

    private let sourceFactory: @MainActor () -> AudioSource

    func start(intent: SessionIntent) async {
        guard phase == .idle else { return }
        do {
            try await MicrophonePermission.request()
        } catch {
            fail("two.ears needs the microphone to measure how loud the room is. Allow it in Settings.")
            return
        }

        self.intent = intent
        pipeline = Pipeline(config: config)
        nudges = NudgeController(config: NudgeConfig(threshold: intent.threshold))
        aggregator = SessionAggregator()
        share = .uncertain
        nudgeCount = 0
        isOverThreshold = false
        isLowBattery = false
        elapsed = 0
        lastSummary = nil
        isEnding = false

        let source = sourceFactory()
        do {
            try source.start { [weak self] samples in
                Task { @MainActor in self?.ingest(samples) }
            }
        } catch {
            pipeline = nil
            fail("The microphone is busy or unavailable.")
            return
        }
        self.source = source
        startedAt = .now

        let runtime = RuntimeSession()
        runtime.onExpire = { [weak self] in self?.end(reason: .interruption) }
        runtime.start()
        self.runtime = runtime

        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        phase = .active
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    func end(reason: SessionEndReason) {
        guard phase == .active, !isEnding, let startedAt, let pipeline else { return }
        isEnding = true
        ticker?.cancel()
        ticker = nil
        source?.stop()
        source = nil
        runtime?.stop()
        runtime = nil
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = false

        aggregator.record(pipeline.finish(), config: config)
        share = pipeline.currentShare
        aggregator.finish(share: share)

        lastSummary = SessionSummaryData(
            id: UUID(),
            startedAt: startedAt,
            endedAt: .now,
            intent: intent,
            talkShare: share.valueOrNil,
            uncertainFraction: aggregator.uncertainFraction,
            longestUserStretch: aggregator.longestUserStretchSeconds,
            nudgeCount: aggregator.nudgeCount,
            nudgesFollowed: aggregator.nudgesFollowed,
            perMinuteShare: aggregator.perMinuteShare,
            endReason: reason)
        self.pipeline = nil
        phase = .ended
        isEnding = false
    }

    func dismissSummary() {
        guard phase == .ended else { return }
        lastSummary = nil
        startedAt = nil
        phase = .idle
    }

    private func fail(_ message: String) {
        startError = message
        isShowingStartError = true
    }

    private var elapsedNow: TimeInterval {
        startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }

    private func ingest(_ samples: [Float]) {
        guard phase == .active, !isEnding, let pipeline else { return }
        let windows = pipeline.process(samples)
        guard !windows.isEmpty else { return }
        aggregator.record(windows, config: config)
        share = pipeline.currentShare
        let now = elapsedNow
        if let tap = nudges.update(share: share, at: now) {
            Haptics.play(tap)
            aggregator.recordNudge(at: now, share: share)
            nudgeCount = aggregator.nudgeCount
        }
        isOverThreshold = nudges.isOverThreshold
    }

    private func tick() {
        guard phase == .active, !isEnding else { return }
        elapsed = elapsedNow
        aggregator.tick(elapsed: elapsed, share: share)

        let battery = WKInterfaceDevice.current().batteryLevel
        if battery >= 0 {
            isLowBattery = battery <= lowBatteryLevel
            if battery <= criticalBatteryLevel {
                end(reason: .battery)
                return
            }
        }
        if elapsed > autoEndAfterSilence, elapsed - aggregator.lastVoicedAt > autoEndAfterSilence {
            end(reason: .autoSilence)
        }
    }
}
