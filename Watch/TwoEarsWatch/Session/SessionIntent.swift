import Foundation

/// What the wearer is trying to do in this room. Sets the nudge threshold.
enum SessionIntent: String, CaseIterable, Identifiable, Codable, Sendable {
    case listen, balanced, presenting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listen: "Listen"
        case .balanced: "Balanced"
        case .presenting: "Presenting"
        }
    }

    var detail: String {
        switch self {
        case .listen: "One tap when you pass 40% of the conversation."
        case .balanced: "One tap when you pass 55% of the conversation."
        case .presenting: "No taps. You're supposed to be talking."
        }
    }

    var symbolName: String {
        switch self {
        case .listen: "ear"
        case .balanced: "bubble.left.and.bubble.right"
        case .presenting: "person.wave.2"
        }
    }

    /// Share of the trailing window that triggers a nudge. nil disables nudges.
    var threshold: Double? {
        switch self {
        case .listen: 0.40
        case .balanced: 0.55
        case .presenting: nil
        }
    }
}
