import WidgetKit
import SwiftUI
import Intents

struct LockScreenWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Button(action: {
            // Open the main app when widget is tapped
            let url = URL(string: "LockScreenMirror://open")!
            UIApplication.shared.open(url)
        }) {
            ZStack {
                Color.black.opacity(0.7)

                VStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 36))

                    Text("Mirror")
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderless)
    }
}

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline with entries for the next hour
        let currentDate = Date()
        for hourOffset in 0..<1 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

@main
struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Lock Screen Mirror")
        .description("Quickly access your mirror on the lock screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .widgetURL(URL(string: "LockScreenMirror://open")!)
    }
}

struct LockScreenWidget_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenWidgetEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}