import Foundation

enum FloatWidgetShared {
    static let appGroupId = "group.com.maddie.floatapp.v1"
    static let snapshotKey = "float:widgetSnapshot:v1"
}

struct FloatWidgetSnapshot: Codable {
    var accountName: String
    var isSinking: Bool
    var sinkingDate: String?
    var todayTitle: String
    var todayDetail: String
    var todayItems: [FloatWidgetEvent]
    var nextTitle: String
    var nextDetail: String
    var updatedAt: Date

    static let placeholder = FloatWidgetSnapshot(
        accountName: "Float",
        isSinking: false,
        sinkingDate: nil,
        todayTitle: "Today",
        todayDetail: "Nothing due today.",
        todayItems: [],
        nextTitle: "Next",
        nextDetail: "Open Float once to refresh.",
        updatedAt: Date()
    )

    static func make(from budget: FloatBudget) -> FloatWidgetSnapshot {
        let account = budget.activeAccount ?? budget.accounts.first ?? FloatBudget.blank.accounts[0]
        let events = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
        let recapEvents = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff(), includeAnchorDate: true)
        let sinkingDate = BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events)
        let todayEvents = recapEvents
            .filter { $0.date == Date.todayString && $0.label != "Confirmed balance" }
            .sorted(by: widgetSort)
        let futureEvents = recapEvents
            .filter { $0.date > Date.todayString && $0.label != "Confirmed balance" }
            .sorted(by: widgetSort)
        let nextEvent = futureEvents.first

        return FloatWidgetSnapshot(
            accountName: account.name,
            isSinking: sinkingDate != nil,
            sinkingDate: sinkingDate,
            todayTitle: todayTitle(for: todayEvents),
            todayDetail: todayDetail(for: todayEvents),
            todayItems: todayEvents.prefix(8).map(FloatWidgetEvent.init(event:)),
            nextTitle: nextEvent.map { "Next: \(labelDate($0.date))" } ?? "Next",
            nextDetail: nextEvent.map { FloatWidgetEvent(event: $0).line } ?? "No upcoming items.",
            updatedAt: Date()
        )
    }

    static func load() -> FloatWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: FloatWidgetShared.appGroupId),
              let data = defaults.data(forKey: FloatWidgetShared.snapshotKey),
              let snapshot = try? JSONDecoder().decode(FloatWidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: FloatWidgetShared.appGroupId),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: FloatWidgetShared.snapshotKey)
    }

    private static func todayTitle(for events: [CashEvent]) -> String {
        guard !events.isEmpty else { return "Today" }
        if events.count == 1 {
            return events[0].type == .income ? "Income Today" : "Due Today"
        }
        return "\(events.count) Items Today"
    }

    private static func todayDetail(for events: [CashEvent]) -> String {
        guard !events.isEmpty else {
            return "Nothing due today."
        }

        let incomeTotal = events.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let billTotal = events.filter { $0.type == .bill }.reduce(0) { $0 + $1.amount }

        if events.count == 1, let event = events.first {
            let prefix = event.type == .income ? "+" : "-"
            return "\(event.label) \(prefix)\(money(event.amount))"
        }

        if incomeTotal > 0, billTotal > 0 {
            return "+\(money(incomeTotal)) in, -\(money(billTotal)) out"
        }

        if incomeTotal > 0 {
            return "+\(money(incomeTotal)) coming in"
        }

        return "-\(money(billTotal)) going out"
    }

    private static func widgetSort(_ lhs: CashEvent, _ rhs: CashEvent) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        }
        if lhs.type != rhs.type {
            return lhs.type == .income
        }
        return lhs.label < rhs.label
    }
}

struct FloatWidgetEvent: Codable, Identifiable {
    var id: String
    var title: String
    var date: String
    var amount: Double
    var isIncome: Bool

    init(event: CashEvent) {
        id = event.id
        title = event.label
        date = event.date
        amount = event.amount
        isIncome = event.type == .income
    }

    var line: String {
        "\(title) \(isIncome ? "+" : "-")\(money(amount))"
    }
}
