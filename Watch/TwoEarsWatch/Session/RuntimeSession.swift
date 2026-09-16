import Foundation
import WatchKit

/// Keeps the app alive with the wrist down. The session type comes from WKBackgroundModes in
/// Info.plist; `mindfulness` is frontmost with a one-hour limit, so the owner renews it on expiry.
@MainActor
final class RuntimeSession: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    var onWillExpire: (@MainActor () -> Void)?
    var onInvalidate: (@MainActor (WKExtendedRuntimeSessionInvalidationReason, Error?) -> Void)?

    var isRunning: Bool { session?.state == .running }
    var expirationDate: Date? { session?.expirationDate }

    func start() {
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
    }

    func stop() {
        let ending = session
        session = nil
        if let ending, ending.state == .running || ending.state == .scheduled {
            ending.invalidate()
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Task { @MainActor in onWillExpire?() }
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                            didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                            error: Error?) {
        let invalidated = ObjectIdentifier(extendedRuntimeSession)
        Task { @MainActor in
            guard let session, ObjectIdentifier(session) == invalidated else { return }
            self.session = nil
            onInvalidate?(reason, error)
        }
    }
}
