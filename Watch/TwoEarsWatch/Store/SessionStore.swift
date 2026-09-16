import Foundation
import SwiftData

enum SessionStore {
    /// Summaries older than this are deleted on launch.
    static let retention: TimeInterval = 30 * 24 * 60 * 60

    @MainActor
    static func save(_ summary: SessionSummaryData, in context: ModelContext) throws {
        context.insert(SessionRecord(summary: summary))
        try context.save()
    }

    @MainActor
    static func prune(in context: ModelContext, now: Date = .now) throws {
        let cutoff = now.addingTimeInterval(-retention)
        try context.delete(model: SessionRecord.self, where: #Predicate { $0.endedAt < cutoff })
        try context.save()
    }

    /// Consecutive most-recent sessions that ended inside their target band.
    /// Presenting sessions have no target and neither extend nor break the streak.
    static func streak(in recordsNewestFirst: [SessionRecord]) -> Int {
        var count = 0
        for record in recordsNewestFirst {
            guard let threshold = record.intent.threshold else { continue }
            guard let share = record.talkShare, share <= threshold else { break }
            count += 1
        }
        return count
    }
}
