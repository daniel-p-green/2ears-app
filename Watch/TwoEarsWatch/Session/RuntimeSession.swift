import Foundation
import WatchKit

/// Keeps the app alive with the wrist down. Needs a WKBackgroundModes entry in Info.plist.
final class RuntimeSession: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    var onExpire: (() -> Void)?

    func start() {
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
    }

    func stop() {
        if let session, session.state == .running {
            session.invalidate()
        }
        session = nil
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        session = nil
        // Foreground use keeps working without a runtime session (the simulator has none),
        // so only an expiry ends the conversation.
        if reason == .expired {
            onExpire?()
        }
    }
}
