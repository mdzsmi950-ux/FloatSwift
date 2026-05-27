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

    var cashBalance: Double
    var leftBeforeNextIncome: Double?
    var nextIncomeDate: String?
    var nextItems: [FloatWidgetEvent]
    var globalIsSinking: Bool
    var globalSinkingAccountName: String?
    var globalSinkingDate: String?

    static let placeholder = FloatWidgetSnapshot(
        accountName: "Float",
        isSinking: false,
        sinkingDate: nil,
        todayTitle: "Floating",
        todayDetail: "Open Float once to refresh.",
        todayItems: [],
        nextTitle: "Status",
        nextDetail: "Floating",
        updatedAt: Date(),
        cashBalance: 0,
        leftBeforeNextIncome: nil,
        nextIncomeDate: nil,
        nextItems: [],
        globalIsSinking: false,
        globalSinkingAccountName: nil,
        globalSinkingDate: nil
    )

    static func make(from budget: FloatBudget) -> FloatWidgetSnapshot {
        let account = budget.activeAccount ?? budget.accounts.first ?? FloatBudget.blank.accounts[0]
        let events = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
            .filter { $0.label != "Confirmed balance" }
            .sorted(by: BudgetMath.eventComesFirst)
        let sinkingDate = BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events)
        let todayEvents = events
            .filter { $0.date == Date.todayString }
            .sorted(by: widgetSort)
        let upcomingEvents = events
            .filter { $0.date >= Date.todayString }
            .sorted(by: widgetSort)
        let futureEvents = events
            .filter { $0.date > Date.todayString }
            .sorted(by: widgetSort)
        let nextEvent = futureEvents.first ?? upcomingEvents.first
        let nextIncome = upcomingEvents.first { $0.type == .income }
        let globalStatus = globalSinkingStatus(for: budget)

        return FloatWidgetSnapshot(
            accountName: account.name,
            isSinking: sinkingDate != nil,
            sinkingDate: sinkingDate,
            todayTitle: todayTitle(for: todayEvents),
            todayDetail: todayDetail(for: todayEvents, nextEvent: nextEvent),
            todayItems: todayEvents.prefix(8).map(FloatWidgetEvent.init(event:)),
            nextTitle: "Status",
            nextDetail: sinkingDate.map { "Sinking \(labelDate($0))" } ?? "Floating",
            updatedAt: Date(),
            cashBalance: account.currentBalance,
            leftBeforeNextIncome: leftBeforeNextIncome(account: account, events: upcomingEvents, nextIncome: nextIncome),
            nextIncomeDate: nextIncome?.date,
            nextItems: upcomingEvents.prefix(8).map(FloatWidgetEvent.init(event:)),
            globalIsSinking: globalStatus.isSinking,
            globalSinkingAccountName: globalStatus.accountName,
            globalSinkingDate: globalStatus.date
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

    private static func leftBeforeNextIncome(account: FloatAccount, events: [CashEvent], nextIncome: CashEvent?) -> Double? {
        guard let nextIncome else { return nil }
        var running = account.currentBalance

        for event in events.sorted(by: BudgetMath.eventComesFirst) where event.date < nextIncome.date {
            running += event.type == .income ? event.amount : -event.amount
        }

        return running
    }

    private static func globalSinkingStatus(for budget: FloatBudget) -> (isSinking: Bool, accountName: String?, date: String?) {
        let statuses = budget.accounts.compactMap { account -> (name: String, date: String)? in
            let events = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
                .filter { $0.label != "Confirmed balance" }
            guard let date = BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events) else {
                return nil
            }
            return (account.name, date)
        }

        guard let earliest = statuses.sorted(by: { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.name < rhs.name
        }).first else {
            return (false, nil, nil)
        }

        return (true, earliest.name, earliest.date)
    }

    private static func todayTitle(for events: [CashEvent]) -> String {
        guard !events.isEmpty else { return "Clear Today" }
        if events.count == 1 {
            return events[0].type == .income ? "Income Today" : "Due Today"
        }
        return "\(events.count) Items Today"
    }

    private static func todayDetail(for events: [CashEvent], nextEvent: CashEvent?) -> String {
        guard !events.isEmpty else {
            guard let nextEvent else { return "Nothing scheduled soon." }
            return "Next \(labelDate(nextEvent.date)) · \(FloatWidgetEvent(event: nextEvent).line)"
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
