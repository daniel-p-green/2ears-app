import SwiftUI
import WidgetKit

/// The one-tap entry point from the watch face. Tapping opens the app straight into a Listen session.
struct StartListeningComplication: Widget {
    static let kind = "com.danielpgreen.twoears.start"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StaticProvider()) { _ in
            ComplicationView()
                .widgetURL(URL(string: "twoears://start"))
        }
        .configurationDisplayName("Start Listening")
        .description("One tap starts a two.ears session.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct StaticEntry: TimelineEntry {
    let date: Date
}

/// The complication never changes, so one entry with no refresh policy.
struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> StaticEntry {
        StaticEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (StaticEntry) -> Void) {
        completion(StaticEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StaticEntry>) -> Void) {
        completion(Timeline(entries: [StaticEntry(date: .now)], policy: .never))
    }
}
