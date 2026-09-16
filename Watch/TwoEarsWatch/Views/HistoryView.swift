import os
import SwiftData
import SwiftUI

struct HistoryView: View {
    private static let logger = Logger(subsystem: "com.danielpgreen.twoears", category: "ui")

    @Environment(\.modelContext) private var context
    @Query(sort: \SessionRecord.endedAt, order: .reverse) private var records: [SessionRecord]

    var body: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    SummaryView(summary: record.summary, isLive: false)
                } label: {
                    HistoryRow(summary: record.summary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("History")
        .containerBackground(Theme.glow.gradient, for: .navigation)
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("No Sessions Yet", systemImage: "ear",
                                       description: Text("Summaries stay for 30 days."))
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(records[index])
        }
        do {
            try context.save()
        } catch {
            Self.logger.error("Could not delete session: \(error.localizedDescription)")
        }
    }
}

private struct HistoryRow: View {
    var summary: SessionSummaryData

    var body: some View {
        HStack(spacing: 10) {
            if let score = summary.score {
                Text(score.value, format: .number)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(score.band.tint)
                    .frame(minWidth: 34, alignment: .leading)
            } else {
                Image(systemName: summary.intent.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.endedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                HStack(spacing: 4) {
                    if let share = summary.talkShare {
                        Text(share, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    } else {
                        Text("Unclear")
                    }
                    Text("·")
                    Text(summary.intent.title)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
