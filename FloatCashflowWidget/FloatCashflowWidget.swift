import SwiftUI
import WidgetKit

struct FloatWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FloatWidgetSnapshot
}

struct FloatWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FloatWidgetEntry {
        FloatWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FloatWidgetEntry) -> Void) {
        completion(FloatWidgetEntry(date: Date(), snapshot: FloatWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FloatWidgetEntry>) -> Void) {
        let entry = FloatWidgetEntry(date: Date(), snapshot: FloatWidgetSnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayRecapWidgetView: View {
    var entry: FloatWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today Recap")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.floatText)

            Spacer(minLength: 0)

            Text(entry.snapshot.todayTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.floatText)
                .lineLimit(2)

            Text(entry.snapshot.todayDetail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.floatTextMid)
                .lineLimit(3)
        }
        .widgetCardBackground()
    }
}

struct FloatStatusWidgetView: View {
    var entry: FloatWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.snapshot.accountName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.floatTextMid)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(entry.snapshot.isSinking ? "Sinking" : "Floating")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(entry.snapshot.isSinking ? Color.floatDanger : Color.floatAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .widgetCardBackground()
    }
}

struct TodayRecapWidget: Widget {
    let kind = "TodayRecapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FloatWidgetProvider()) { entry in
            TodayRecapWidgetView(entry: entry)
        }
        .configurationDisplayName("Today Recap")
        .description("See what is due or arriving today.")
        .supportedFamilies([.systemSmall])
    }
}

struct FloatStatusWidget: Widget {
    let kind = "FloatStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FloatWidgetProvider()) { entry in
            FloatStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Floating Status")
        .description("See whether your active account is floating or sinking.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct FloatCashflowWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayRecapWidget()
        FloatStatusWidget()
    }
}

private extension View {
    func widgetCardBackground() -> some View {
        self
            .padding(14)
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [Color(hex: "EEE9E7"), .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}
