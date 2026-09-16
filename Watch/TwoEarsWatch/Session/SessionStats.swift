import Foundation
import TwoEarsCore

/// Running aggregates over emitted windows. Holds no audio.
struct SessionStats {
    private(set) var totalWindows = 0
    private(set) var uncertainWindows = 0
    /// Seconds into the session of the last voiced window.
    private(set) var lastVoicedAt: TimeInterval = 0
    private(set) var longestUserStretch: TimeInterval = 0
    var perMinuteShare: [Double?] = []
    var nudgesFollowed = 0

    /// Pauses of up to this many windows do not break a stretch of the wearer's speech.
    private let stretchGapAllowance = 10
    private var currentStretchWindows = 0
    private var gapWindows = 0

    var uncertainFraction: Double {
        totalWindows > 0 ? Double(uncertainWindows) / Double(totalWindows) : 0
    }

    mutating func record(_ windows: [WindowStat], windowSeconds: Double) {
        for window in windows {
            totalWindows += 1
            if window.voiced {
                lastVoicedAt = Double(window.startMs) / 1000
            }
            if window.attribution == .uncertain {
                uncertainWindows += 1
            }
            if window.attribution == .user {
                currentStretchWindows += 1 + gapWindows
                gapWindows = 0
                longestUserStretch = max(longestUserStretch, Double(currentStretchWindows) * windowSeconds)
            } else if currentStretchWindows > 0 {
                gapWindows += 1
                if gapWindows > stretchGapAllowance {
                    currentStretchWindows = 0
                    gapWindows = 0
                }
            }
        }
    }
}
