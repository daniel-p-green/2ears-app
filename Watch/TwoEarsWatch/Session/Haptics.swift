import TwoEarsCore
import WatchKit

/// The only place that plays haptics. No sound, ever.
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
