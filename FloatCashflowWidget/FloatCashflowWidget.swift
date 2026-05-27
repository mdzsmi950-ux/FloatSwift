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
    @Environment(\.widgetFamily) private var family
    var entry: FloatWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today Recap")
                    .font(.system(size: family == .systemSmall ? 12 : 14, weight: .semibold))
                    .foregroundStyle(Color.floatText)
                Spacer()
                if family != .systemSmall {
                    Text(entry.snapshot.accountName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.floatTextFaint)
                        .lineLimit(1)
                }
            }

            Text(entry.snapshot.todayTitle)
                .font(.system(size: family == .systemSmall ? 17 : 20, weight: .bold))
                .foregroundStyle(Color.floatText)
                .lineLimit(2)

            Text(entry.snapshot.todayDetail)
                .font(.system(size: family == .systemSmall ? 12 : 13, weight: .medium))
                .foregroundStyle(Color.floatTextMid)
                .lineLimit(2)

            if family == .systemSmall {
                Spacer(minLength: 0)
            } else {
                if !entry.snapshot.todayItems.isEmpty {
                    eventList(limit: 3)
                }
                Spacer(minLength: 0)
                statusFooter
            }
        }
        .widgetCardBackground()
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider()
                .opacity(0.35)
            Text(entry.snapshot.nextDetail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entry.snapshot.isSinking ? Color.floatDanger : Color.floatAccent)
                .lineLimit(1)
        }
    }

    private func eventList(limit: Int) -> some View {
        VStack(spacing: 7) {
            ForEach(entry.snapshot.todayItems.prefix(limit)) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.isIncome ? Color.floatAccent : Color.floatTextSubtle)
                        .frame(width: 6, height: 6)
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.floatText)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(item.isIncome ? "+" : "-")\(money(item.amount))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isIncome ? Color.floatAccent : Color.floatTextMid)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FloatCashflowWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayRecapWidget()
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
