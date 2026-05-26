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
    var updatedAt: Date

    static let placeholder = FloatWidgetSnapshot(
        accountName: "Float",
        isSinking: false,
        sinkingDate: nil,
        todayTitle: "Today",
        todayDetail: "Open Float to build your timeline.",
        updatedAt: Date()
    )

    static func make(from budget: FloatBudget) -> FloatWidgetSnapshot {
        let account = budget.activeAccount ?? budget.accounts.first ?? FloatBudget.blank.accounts[0]
        let events = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
        let sinkingDate = BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events)
        let todayEvents = events
            .filter { $0.date == Date.todayString && $0.label != "Confirmed balance" }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type == .income
                }
                return lhs.label < rhs.label
            }

        return FloatWidgetSnapshot(
            accountName: account.name,
            isSinking: sinkingDate != nil,
            sinkingDate: sinkingDate,
            todayTitle: todayTitle(for: todayEvents),
            todayDetail: todayDetail(for: todayEvents),
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
}
