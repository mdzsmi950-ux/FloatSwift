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
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : family == .systemLarge ? 12 : 9) {
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
                .font(.system(size: family == .systemSmall ? 17 : family == .systemLarge ? 24 : 20, weight: .bold))
                .foregroundStyle(Color.floatText)
                .lineLimit(2)

            Text(entry.snapshot.todayDetail)
                .font(.system(size: family == .systemSmall ? 12 : 13, weight: .medium))
                .foregroundStyle(Color.floatTextMid)
                .lineLimit(2)

            if family == .systemSmall {
                Spacer(minLength: 0)
            } else if entry.snapshot.todayItems.isEmpty {
                emptyTodayView
            } else {
                eventList(limit: family == .systemLarge ? 6 : 3)
            }

            Spacer(minLength: 0)

            if family != .systemSmall {
                Divider()
                    .opacity(0.35)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.snapshot.nextTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.floatTextFaint)
                        .textCase(.uppercase)
                    Text(entry.snapshot.nextDetail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.floatTextMid)
                        .lineLimit(2)
                }
            }
        }
        .widgetCardBackground()
    }

    private var emptyTodayView: some View {
        Text("No bills, debts, or income scheduled for today.")
            .font(.system(size: 12))
            .foregroundStyle(Color.floatTextFaint)
            .lineLimit(2)
            .padding(.top, 2)
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

struct FloatStatusWidgetView: View {
    var entry: FloatWidgetEntry

    var body: some View {
        ZStack {
            Text(entry.snapshot.isSinking ? "Sinking" : "Floating")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(entry.snapshot.isSinking ? Color.floatDanger : Color.floatAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        .supportedFamilies([.systemSmall, .accessoryRectangular])
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
