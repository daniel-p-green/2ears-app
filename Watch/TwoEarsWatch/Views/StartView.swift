import os
import SwiftData
import SwiftUI

struct StartView: View {
    private static let logger = Logger(subsystem: "com.danielpgreen.twoears", category: "ui")

    @Environment(SessionManager.self) private var session
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionRecord.endedAt, order: .reverse) private var records: [SessionRecord]

    private var streak: Int { SessionStore.streak(in: records) }

    var body: some View {
        @Bindable var session = session
        List {
            Section {
                ForEach(SessionIntent.allCases) { intent in
                    Button {
                        start(intent)
                    } label: {
                        IntentCard(intent: intent)
                    }
                    .disabled(session.phase == .starting)
                }
            } footer: {
                Text("One tap on the wrist when you pass your share. Nothing is recorded.")
            }

            Section {
                NavigationLink {
                    HistoryView()
                } label: {
                    LabeledContent("History") {
                        Text(records.count, format: .number)
                    }
                }
            } footer: {
                if streak > 0 {
                    Label("^[\(streak) room](inflect: true) listened well", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("two.ears")
        .containerBackground(Theme.glow.gradient, for: .navigation)
        .task {
            do {
                try SessionStore.prune(in: context)
            } catch {
                Self.logger.error("Could not prune history: \(error.localizedDescription)")
            }
        }
        .alert("Couldn't Start", isPresented: $session.isShowingStartError) {
        } message: {
            Text(session.startError)
        }
    }

    private func start(_ intent: SessionIntent) {
        Task {
            await session.start(intent: intent)
        }
    }
}
