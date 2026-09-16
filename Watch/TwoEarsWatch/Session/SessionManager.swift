import Foundation
import Observation
import TwoEarsCore
import WatchKit

/// Owns the session lifecycle and the app state machine: idle, active, ended.
@Observable
@MainActor
final class SessionManager {
    enum Phase: Equatable {
        case idle, active, ended
    }

    private(set) var phase: Phase = .idle
    private(set) var intent: SessionIntent = .listen
    private(set) var share: TalkShare = .uncertain
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0
    private(set) var nudgeCount = 0
    private(set) var isOverThreshold = false
    private(set) var lastSummary: SessionSummaryData?
    var startError: String?

    /// Seconds of silence before a session ends itself.
    var autoEndAfterSilence: TimeInterval = 180
    /// A nudge counts as followed when share drops this much within two minutes.
    var followedDrop = 0.05

    private let config = ClassifierConfig.default
    private var pipeline: Pipeline?
    private var source: AudioSource?
    private var nudges = NudgeController(threshold: nil)
    private var runtime: RuntimeSession?
    private var ticker: Task<Void, Never>?
    private var stats = SessionStats()
    private var pendingNudgeChecks: [(due: TimeInterval, shareAtNudge: Double)] = []

    func start(intent: SessionIntent) async {
        guard phase != .active else { return }
        do {
            try await MicrophonePermission.request()
        } catch {
            startError = "2Ears needs the microphone to measure how loud the room is. Allow it in Settings."
            return
        }

        self.intent = intent
        pipeline = Pipeline(config: config)
        nudges = NudgeController(threshold: intent.threshold)
        stats = SessionStats()
        pendingNudgeChecks = []
        share = .uncertain
        nudgeCount = 0
        isOverThreshold = false
        elapsed = 0
        startedAt = .now
        lastSummary = nil

        let source = AudioSources.make()
        do {
            try source.start { [weak self] samples in
                Task { @MainActor in self?.ingest(samples) }
            }
        } catch {
            startError = "The microphone is busy or unavailable."
            return
        }
        self.source = source

        let runtime = RuntimeSession()
        runtime.onExpire = { [weak self] in self?.end(reason: .interruption) }
        runtime.start()
        self.runtime = runtime

        phase = .active
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func end(reason: SessionEndReason) {
        guard phase == .active, let startedAt, let pipeline else { return }
        ticker?.cancel()
        ticker = nil
        source?.stop()
        source = nil
        runtime?.stop()
        runtime = nil

        stats.record(pipeline.finish(), windowSeconds: config.windowSeconds)
        share = pipeline.currentShare
        resolvePendingNudges(upTo: .infinity)

        let talkShare: Double? = if case .value(let v) = share { v } else { nil }
        lastSummary = SessionSummaryData(
            id: UUID(),
            startedAt: startedAt,
            endedAt: .now,
            intent: intent,
            talkShare: talkShare,
            uncertainFraction: stats.uncertainFraction,
            longestUserStretch: stats.longestUserStretch,
            nudgeCount: nudgeCount,
            nudgesFollowed: stats.nudgesFollowed,
            perMinuteShare: stats.perMinuteShare,
            endReason: reason)
        self.pipeline = nil
        phase = .ended
    }

    func dismissSummary() {
        lastSummary = nil
        startedAt = nil
        phase = .idle
    }

    private var elapsedNow: TimeInterval {
        startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }

    private func ingest(_ samples: [Float]) {
        guard phase == .active, let pipeline else { return }
        let windows = pipeline.process(samples)
        guard !windows.isEmpty else { return }
        stats.record(windows, windowSeconds: config.windowSeconds)
        share = pipeline.currentShare
        let now = elapsedNow
        if let tap = nudges.update(share: share, at: now) {
            Haptics.play(tap)
            nudgeCount += 1
            if case .value(let value) = share {
                pendingNudgeChecks.append((due: now + 120, shareAtNudge: value))
            }
        }
        isOverThreshold = nudges.isOverThreshold
    }

    private func tick() {
        guard phase == .active else { return }
        elapsed = elapsedNow
        let minute = Int(elapsed / 60)
        while stats.perMinuteShare.count < minute {
            let value: Double? = if case .value(let v) = share { v } else { nil }
            stats.perMinuteShare.append(value)
        }
        resolvePendingNudges(upTo: elapsed)
        if elapsed > autoEndAfterSilence, elapsed - stats.lastVoicedAt > autoEndAfterSilence {
            end(reason: .autoSilence)
        }
    }

    private func resolvePendingNudges(upTo time: TimeInterval) {
        let current: Double? = if case .value(let v) = share { v } else { nil }
        let due = pendingNudgeChecks.filter { $0.due <= time }
        pendingNudgeChecks.removeAll { $0.due <= time }
        for check in due {
            if let current, current <= check.shareAtNudge - followedDrop {
                stats.nudgesFollowed += 1
            }
        }
    }
}

enum Haptics {
    @MainActor
    static func play(_ tap: NudgeController.Tap) {
        let device = WKInterfaceDevice.current()
        switch tap {
        case .single:
            device.play(.notification)
        case .double:
            device.play(.notification)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                device.play(.notification)
            }
        }
    }
}
