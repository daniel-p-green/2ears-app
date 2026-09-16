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
            Section {
                ForEach(SessionIntent.allCases) { intent in
                    Button {
                        start(intent)
                    } label: {
                        IntentCard(intent: intent)
                    }
                    .disabled(isStarting)
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
        .containerBackground(Color.accentColor.gradient, for: .navigation)
        .task {
            try? SessionStore.prune(in: context)
        }
        .alert("Couldn't Start", isPresented: $session.isShowingStartError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.startError)
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
