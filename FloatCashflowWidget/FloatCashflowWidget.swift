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

    private var snapshot: FloatWidgetSnapshot {
        entry.snapshot
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallStatusView
            case .systemMedium:
                mediumStatusView
            default:
                largeStatusView
            }
        }
        .widgetCardBackground()
    }

    private var smallStatusView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(snapshot.globalIsSinking ? "Sinking" : "Floating")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(snapshot.globalIsSinking ? Color.floatDanger : Color.floatAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader

            HStack(alignment: .top, spacing: 12) {
                metric(label: "Cash balance", value: money(snapshot.cashBalance))
                    .frame(maxWidth: .infinity, alignment: .leading)
                metric(label: "Before income", value: leftBeforeIncomeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Next")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.floatTextFaint)
                nextItemsList(limit: 3)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var largeStatusView: some View {
        VStack(alignment: .leading, spacing: 9) {
            widgetHeader

            HStack(alignment: .top, spacing: 10) {
                metricCard(label: "Cash balance", value: money(snapshot.cashBalance))
                metricCard(label: "Before next income", value: leftBeforeIncomeText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Next items")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.floatTextFaint)
                nextItemsList(limit: 10)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var widgetHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(snapshot.accountName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.floatText)
                .lineLimit(1)
            Spacer()
            Text(snapshot.globalIsSinking ? "Needs attention" : "All floating")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(snapshot.globalIsSinking ? Color.floatDanger : Color.floatAccent)
                .lineLimit(1)
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.floatTextFaint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.floatText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.floatTextFaint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.floatText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.05), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func nextItemsList(limit: Int) -> some View {
        let items = Array(snapshot.nextItems.prefix(limit))
        if items.isEmpty {
            Text("Nothing scheduled soon.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.floatTextMid)
                .lineLimit(2)
        } else {
            VStack(spacing: family == .systemMedium ? 4 : 5) {
                ForEach(items) { item in
                    HStack(spacing: 7) {
                        Text(labelDate(item.date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.floatTextFaint)
                            .frame(width: family == .systemMedium ? 34 : 38, alignment: .leading)
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.floatText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 4)
                        Text("\(item.isIncome ? "+" : "-")\(money(item.amount))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(item.isIncome ? Color.floatAccent : Color.floatTextMid)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
        }
    }

    private var leftBeforeIncomeText: String {
        guard let left = snapshot.leftBeforeNextIncome else {
            return "No income scheduled"
        }
        return money(left)
    }
}

struct TodayRecapWidget: Widget {
    let kind = "TodayRecapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FloatWidgetProvider()) { entry in
            TodayRecapWidgetView(entry: entry)
        }
        .configurationDisplayName("Float Status")
        .description("See whether your cash-flow timeline is floating or sinking.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
