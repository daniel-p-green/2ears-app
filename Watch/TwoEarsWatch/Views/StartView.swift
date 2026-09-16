import SwiftData
import SwiftUI

struct StartView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionRecord.endedAt, order: .reverse) private var records: [SessionRecord]
    @State private var isStarting = false

    private var streak: Int { SessionStore.streak(in: records) }

    var body: some View {
        @Bindable var session = session
        List {
            ForEach(SessionIntent.allCases) { intent in
                Button {
                    start(intent)
                } label: {
                    IntentCard(intent: intent)
                }
                .buttonStyle(.plain)
                .disabled(isStarting)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(intent.tint.gradient)
                )
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
        .navigationTitle("2Ears")
        .containerBackground(.blue.gradient, for: .navigation)
        .task {
            try? SessionStore.prune(in: context)
        }
        .alert("Couldn't Start", isPresented: Binding(
            get: { session.startError != nil },
            set: { if !$0 { session.startError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.startError ?? "")
        }
    }

    private func start(_ intent: SessionIntent) {
        isStarting = true
        Task {
            await session.start(intent: intent)
            isStarting = false
        }
    }
}
