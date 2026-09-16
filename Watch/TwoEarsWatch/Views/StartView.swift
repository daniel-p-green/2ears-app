import SwiftData
import SwiftUI

struct StartView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.modelContext) private var context
    @Query(sort: \SessionRecord.endedAt, order: .reverse) private var records: [SessionRecord]
    @AppStorage("intent") private var intentRawValue = SessionIntent.listen.rawValue
    @State private var isStarting = false

    private var intent: SessionIntent {
        get { SessionIntent(rawValue: intentRawValue) ?? .listen }
        nonmutating set { intentRawValue = newValue.rawValue }
    }

    private var streak: Int { SessionStore.streak(in: records) }

    var body: some View {
        @Bindable var session = session
        List {
            Section {
                Button {
                    start()
                } label: {
                    Label("Start Listening", systemImage: "ear")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStarting)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Intent", selection: Binding(get: { intent }, set: { intent = $0 })) {
                    ForEach(SessionIntent.allCases) { intent in
                        Label(intent.title, systemImage: intent.symbolName)
                            .tag(intent)
                    }
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text(intent.detail)
            }

            Section {
                NavigationLink {
                    HistoryView()
                } label: {
                    LabeledContent("History") {
                        Text(records.count, format: .number)
                    }
                }
                if streak > 0 {
                    Label {
                        Text("^[\(streak) room](inflect: true) where you listened well")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                    .font(.footnote)
                }
            }
        }
        .navigationTitle("2Ears")
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

    private func start() {
        isStarting = true
        let chosen = intent
        Task {
            await session.start(intent: chosen)
            isStarting = false
        }
    }
}
