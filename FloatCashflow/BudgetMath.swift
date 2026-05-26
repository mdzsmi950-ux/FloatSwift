import Foundation

enum BudgetMath {
    static func reservePercent(_ account: FloatAccount) -> Double {
        guard account.reserveGoal > 0 else { return 0 }
        return min(100, (account.reserveBalance / account.reserveGoal) * 100)
    }

    static func dueReserveTransfers(account: FloatAccount, currentDate: String = Date.todayString) -> [CashEvent] {
        buildEvents(account: account, cutoff: currentDate)
            .filter { $0.type == .bill }
            .filter { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "transfer to reserve" }
            .filter { !account.appliedReserveTransfers.contains($0.id) }
    }

    static func cutoff(from date: Date = Date()) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)) ?? date
        let plusTwoMonths = calendar.date(byAdding: .month, value: 2, to: start) ?? start
        let components = calendar.dateComponents([.year, .month], from: plusTwoMonths)
        let monthStart = calendar.date(from: components) ?? plusTwoMonths
        let lastDayPreviousMonth = calendar.date(byAdding: .day, value: -1, to: monthStart) ?? plusTwoMonths
        return lastDayPreviousMonth.ymdString
    }

    static func nextDate(_ date: String, frequency: Frequency) -> String? {
        guard frequency != .oneTime, let parsed = Date.yyyyMMdd.date(from: date) else { return nil }
        var components = DateComponents()

        switch frequency {
        case .oneTime:
            return nil
        case .weekly:
            components.day = 7
        case .biweekly:
            components.day = 14
        case .monthly:
            components.month = 1
        case .quarterly:
            components.month = 3
        case .semiannual:
            components.month = 6
        case .annual:
            components.year = 1
        }

        return Calendar(identifier: .gregorian)
            .date(byAdding: components, to: parsed)?
            .ymdString
    }

    static func nextRecurringDate(startDate: String, frequency: Frequency, currentDate: String) -> String {
        var date = startDate
        while date <= currentDate {
            if frequency == .oneTime { return startDate }
            guard let next = nextDate(date, frequency: frequency) else { return startDate }
            date = next
        }
        return date
    }

    static func nextUnpaidBillDate(
        bill: BudgetBill,
        currentDate: String = Date.todayString,
        paidEarlyBills: [PaidEarlyBill]
    ) -> String {
        var date = nextRecurringDate(
            startDate: bill.startDate,
            frequency: bill.frequency,
            currentDate: currentDate
        )

        while paidEarlyBills.contains(where: { $0.billId == bill.id && $0.originalDate == date }) {
            if bill.frequency == .oneTime { return "" }
            guard let next = nextDate(date, frequency: bill.frequency) else { return "" }
            date = next
        }

        return date
    }

    static func buildEvents(account: FloatAccount, cutoff: String) -> [CashEvent] {
        var events: [CashEvent] = []
        let startDate = account.lastConfirmedDate ?? Date.todayString

        for bill in account.bills where bill.active {
            var date = nextRecurringDate(
                startDate: bill.startDate,
                frequency: bill.frequency,
                currentDate: startDate
            )

            while date <= cutoff {
                let wasPaidEarly = account.paidEarlyBills.contains {
                    $0.billId == bill.id && $0.originalDate == date
                }

                if date > startDate, !wasPaidEarly {
                    events.append(CashEvent(
                        id: "\(bill.id)-\(date)",
                        type: .bill,
                        label: bill.name,
                        amount: bill.amount,
                        date: date
                    ))
                }

                guard bill.frequency != .oneTime, let next = nextDate(date, frequency: bill.frequency) else {
                    break
                }
                date = next
            }
        }

        for item in account.income where item.active {
            var date = nextRecurringDate(
                startDate: item.startDate,
                frequency: item.frequency,
                currentDate: startDate
            )

            while date <= cutoff {
                if date > startDate {
                    events.append(CashEvent(
                        id: "\(item.id)-\(date)",
                        type: .income,
                        label: item.label,
                        amount: item.amount,
                        date: date
                    ))
                }

                guard item.frequency != .oneTime, let next = nextDate(date, frequency: item.frequency) else {
                    break
                }
                date = next
            }
        }

        return events.sorted(by: eventComesFirst)
    }

    static func sinkingDate(startingBalance: Double, events: [CashEvent]) -> String? {
        var running = startingBalance
        for event in events.sorted(by: eventComesFirst) {
            running += event.type == .income ? event.amount : -event.amount
            if running < 0 { return event.date }
        }
        return nil
    }

    static func eventComesFirst(_ lhs: CashEvent, _ rhs: CashEvent) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.type == rhs.type { return lhs.id < rhs.id }
        return lhs.type == .income
    }
}
