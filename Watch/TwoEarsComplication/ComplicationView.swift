import SwiftUI
import WidgetKit

/// One glyph, every family. Watch faces tint it themselves.
struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "ear")
                        .font(.title2.weight(.medium))
                }
            case .accessoryCorner:
                Image(systemName: "ear")
                    .font(.title.weight(.medium))
                    .widgetLabel {
                        Text("Listen")
                    }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "ear")
                        .font(.title2.weight(.medium))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("two.ears")
                            .font(.headline)
                        Text("Tap to listen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            default:
                Label("Listen", systemImage: "ear")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityLabel("Start listening with two.ears")
    }
}
