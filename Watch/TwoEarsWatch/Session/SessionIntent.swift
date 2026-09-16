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

    /// Short line for the start row.
    var cardDetail: String {
        switch self {
        case .listen: "Tap past 40%"
        case .balanced: "Tap past 55%"
        case .presenting: "Stats only"
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
