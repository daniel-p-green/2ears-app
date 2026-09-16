import AppIntents
import Foundation

/// "Start listening" from Siri or a Shortcut. Opens the app straight into a Listen session.
struct StartListeningIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Listening"
    static let description = IntentDescription("Starts a two.ears session with the Listen intent.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await SessionManager.shared.start(intent: .listen)
        return .result()
    }
}

struct TwoEarsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartListeningIntent(),
            phrases: [
                "Start listening with \(.applicationName)",
                "\(.applicationName) start listening",
            ],
            shortTitle: "Start Listening",
            systemImageName: "ear")
    }
}
