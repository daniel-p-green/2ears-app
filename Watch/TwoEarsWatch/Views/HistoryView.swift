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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.endedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                        HStack(spacing: 4) {
                            if let share = record.talkShare {
                                Text(share, format: .percent.precision(.fractionLength(0)))
                                    .monospacedDigit()
                            } else {
                                Text("Uncertain")
                            }
                            Text("·")
                            Text(record.intent.title)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("History")
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
