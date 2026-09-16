import Foundation
import Observation
import os
import SwiftData
import TwoEarsCore
import WatchKit

/// Owns the session lifecycle and the app state machine: idle, starting, active, ended.
/// Everything it publishes derives from window aggregates; no audio is retained.
@Observable
@MainActor
final class SessionManager {
    enum Phase: Equatable {
        case idle, starting, active, ended
    }

    enum StartRequest: Equatable {
        case started, queuedUntilActive, alreadyActive, summaryPending
    }

    static let shared = SessionManager()
    private static let logger = Logger(subsystem: "com.danielpgreen.twoears", category: "session")

    private(set) var phase: Phase = .idle
    private(set) var intent: SessionIntent = .listen
    private(set) var share: TalkShare = .uncertain
    private(set) var startedAt: Date?
    private(set) var nudgeCount = 0
    private(set) var isOverThreshold = false
    private(set) var isLowBattery = false
    private(set) var lastSummary: SessionSummaryData?
    var isShowingStartError = false
    private(set) var startError = ""

    /// Where finished summaries are saved. Set once by the app at launch.
    var modelContainer: ModelContainer?

    /// Pipeline seconds of silence before a session ends itself.
    var autoEndAfterSilence: Double = 180
    /// Battery fraction at which the controls page warns.
    var lowBatteryLevel: Float = 0.20
    /// Battery fraction at which the session ends itself to protect the day.
    var criticalBatteryLevel: Float = 0.05

    private let config = ClassifierConfig.default
    private let sourceFactory: @MainActor () -> AudioSource
    private var pipeline: Pipeline?
    private var source: AudioSource?
    private var sampleContinuation: AsyncStream<[Float]>.Continuation?
    private var consumer: Task<Void, Never>?
    private var nudges = NudgeController(config: NudgeConfig(threshold: nil))
    private var aggregator = SessionAggregator()
    private var runtime: RuntimeSession?
    private var ticker: Task<Void, Never>?
    private var needsRuntimeRestart = false
    private var pendingIntent: SessionIntent?

    init(sourceFactory: @escaping @MainActor () -> AudioSource = AudioSources.make) {
        self.sourceFactory = sourceFactory
    }

    /// Entry point for Siri and complications, which may run before the scene is active.
    func requestStart(intent: SessionIntent) -> StartRequest {
        switch phase {
        case .active, .starting:
            return .alreadyActive
        case .ended:
            return .summaryPending
        case .idle:
            if WKApplication.shared().applicationState == .active {
                Task { await start(intent: intent) }
                return .started
            }
            pendingIntent = intent
            return .queuedUntilActive
        }
    }

    func start(intent: SessionIntent) async {
        guard phase == .idle else { return }
        phase = .starting
        pendingIntent = nil
        do {
            try await MicrophonePermission.request()
        } catch {
            fail("two.ears needs the microphone to measure how loud the room is. Allow it in Settings.")
            return
        }
        guard phase == .starting else { return }

        self.intent = intent
        pipeline = Pipeline(config: config)
        nudges = NudgeController(config: NudgeConfig(threshold: intent.threshold))
        aggregator = SessionAggregator()
        share = .uncertain
        nudgeCount = 0
        isOverThreshold = false
        isLowBattery = false
        lastSummary = nil
        needsRuntimeRestart = false

        // One ordered stream from the audio thread to the main actor; per-buffer Tasks would not
        // guarantee the sample order the pipeline depends on.
        let (stream, continuation) = AsyncStream<[Float]>.makeStream(bufferingPolicy: .unbounded)
        sampleContinuation = continuation
        consumer = Task { [weak self] in
            for await samples in stream {
                guard let self, !Task.isCancelled else { return }
                self.ingest(samples)
            }
        }

        let source = sourceFactory()
        do {
            try source.start { samples in continuation.yield(samples) }
        } catch {
            consumer?.cancel()
            continuation.finish()
            pipeline = nil
            fail("The microphone is busy or unavailable.")
            return
        }
        self.source = source
        startedAt = .now
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        phase = .active
        startRuntime()

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    func end(reason: SessionEndReason) {
        guard phase == .active, let startedAt, let pipeline else { return }
        phase = .ended
        ticker?.cancel()
        ticker = nil
        consumer?.cancel()
        consumer = nil
        sampleContinuation?.finish()
        sampleContinuation = nil
        source?.stop()
        source = nil
        runtime?.stop()
        runtime = nil
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = false

        aggregator.record(pipeline.finish(), config: config)
        share = pipeline.currentShare
        aggregator.finish(elapsed: aggregator.pipelineSeconds, share: share)
        self.pipeline = nil

        let summary = SessionSummaryData(
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
        lastSummary = summary
        persist(summary)
    }

    func dismissSummary() {
        guard phase == .ended else { return }
        lastSummary = nil
        startedAt = nil
        phase = .idle
    }

    /// Call when the scene becomes active: starts a queued Siri request and repairs anything the
    /// system stopped while the app was away.
    func appBecameActive() {
        if let pendingIntent, phase == .idle {
            self.pendingIntent = nil
            Task { await start(intent: pendingIntent) }
            return
        }
        guard phase == .active else { return }
        source?.resume()
        if needsRuntimeRestart || runtime?.isRunning != true {
            needsRuntimeRestart = false
            startRuntime()
        }
    }

    private func startRuntime() {
        runtime?.stop()
        let runtime = RuntimeSession()
        runtime.onInvalidate = { [weak self] reason, error in
            self?.runtimeInvalidated(reason: reason, error: error)
        }
        runtime.start()
        self.runtime = runtime
    }

    private func runtimeInvalidated(reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        guard phase == .active else { return }
        if let error {
            // A wrong WKBackgroundModes value shows up here as "not approved to start session".
            Self.logger.error("Runtime session invalidated (\(reason.rawValue)): \(error.localizedDescription)")
            return
        }
        // Expired or lost frontmost status: renew now if we are on screen, otherwise on return.
        if WKApplication.shared().applicationState == .active {
            startRuntime()
        } else {
            needsRuntimeRestart = true
        }
    }

    private func persist(_ summary: SessionSummaryData) {
        guard let modelContainer else {
            Self.logger.error("No model container; summary not saved")
            return
        }
        do {
            try SessionStore.save(summary, in: ModelContext(modelContainer))
        } catch {
            Self.logger.error("Could not save summary: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        phase = .idle
        startError = message
        isShowingStartError = true
    }

    private var sessionSeconds: Double {
        startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }

    private func ingest(_ samples: [Float]) {
        guard phase == .active, let pipeline else { return }
        let windows = pipeline.process(samples)
        guard !windows.isEmpty else { return }
        aggregator.record(windows, config: config)
        let newShare = pipeline.currentShare
        if newShare != share {
            share = newShare
        }
        if let tap = nudges.update(share: newShare, at: aggregator.pipelineSeconds) {
            Haptics.play(tap)
            aggregator.recordNudge(at: aggregator.pipelineSeconds, share: newShare)
            nudgeCount = aggregator.nudgeCount
        }
        if nudges.isOverThreshold != isOverThreshold {
            isOverThreshold = nudges.isOverThreshold
        }
    }

    private func tick() {
        guard phase == .active else { return }
        // Pipeline time, not wall time: a paused microphone must not read as silence.
        let now = aggregator.pipelineSeconds
        aggregator.tick(elapsed: now, share: share)

        let battery = WKInterfaceDevice.current().batteryLevel
        if battery >= 0 {
            let low = battery <= lowBatteryLevel
            if low != isLowBattery { isLowBattery = low }
            if battery <= criticalBatteryLevel {
                end(reason: .battery)
                return
            }
        }
        if now > autoEndAfterSilence, now - aggregator.lastVoicedAt > autoEndAfterSilence {
            end(reason: .autoSilence)
        }
    }
}
