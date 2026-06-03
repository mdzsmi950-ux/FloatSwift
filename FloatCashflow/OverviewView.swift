import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: BudgetStore
    var startOwnBudget: () -> Void
    @State private var measuredDateColumnWidth: CGFloat = 0
    @State private var measuredAmountColumnWidth: CGFloat = 0

    private enum TimelineSpacing {
        static let rowGap: CGFloat = 8
        static let balanceTopGap: CGFloat = 8
        static let balanceBottomGap: CGFloat = 10
        static let chunkTopGap: CGFloat = 10
        static let dividerBottomGap: CGFloat = 10
    }

    private var account: FloatAccount {
        store.activeAccount
    }

    private var events: [CashEvent] {
        BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
    }

    private var sinkingDate: String? {
        BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events)
    }

    private var reservePercent: Double {
        BudgetMath.reservePercent(account)
    }

    private var hasIncome: Bool {
        account.income.contains { $0.active && $0.label != "Confirmed balance" }
    }

    private var dateColumnWidth: CGFloat {
        max(34, measuredDateColumnWidth)
    }

    private var amountColumnWidth: CGFloat {
        max(72, measuredAmountColumnWidth)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    header
                    reserveCard
                    if hasIncome {
                        timeline
                    } else {
                        noIncomeState
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 146)
                .frame(minHeight: proxy.size.height + 1, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .onPreferenceChange(DateColumnWidthPreferenceKey.self) { width in
                measuredDateColumnWidth = ceil(width)
            }
            .onPreferenceChange(AmountColumnWidthPreferenceKey.self) { width in
                measuredAmountColumnWidth = ceil(width)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overview")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.floatText)

                Spacer()

                if store.isDemoMode {
                    Button("Let's Go", action: startOwnBudget)
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Color.floatText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if !hasIncome {
                    Text("Add income to start")
                } else if let sinkingDate {
                    Text("Sinking \(longDate(sinkingDate))!")
                    Text("Cut Back Spending Now!")
                } else {
                    Text("Floating")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(headerStatusColor)
        }
    }

    private var headerStatusColor: Color {
        if !hasIncome {
            return Color.floatTextSubtle
        }
        return sinkingDate == nil ? Color.floatTextSubtle : Color.floatWarning
    }

    private var reserveCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                metric(label: "Reserve", value: money(account.reserveBalance), color: .floatAccent)
                Spacer()
                metric(label: "Goal", value: account.reserveGoal > 0 ? money(account.reserveGoal) : "-", color: .floatTextMid)
                    .multilineTextAlignment(.trailing)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.08))
                    Capsule()
                        .fill(Color.floatAccent)
                        .frame(width: proxy.size.width * reservePercent / 100)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .floatCardSurface(cornerRadius: 18, fillOpacity: 0.82)
    }

    private var noIncomeState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No income added yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.floatText)

            Text("Add your paycheck or other regular income in In. Then Float can show what happens before and after money comes in.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.floatTextMid)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                noIncomeHintRow("Cash balance is only the starting point.")
                noIncomeHintRow("Income gives the timeline its next refill.")
                noIncomeHintRow("Bills and cards make more sense after that.")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .floatCardSurface(cornerRadius: 18, fillOpacity: 0.82)
    }

    private func noIncomeHintRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(Color.floatTextFaint.opacity(0.48))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.floatTextFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeline: some View {
        let groups = groupedEvents()

        return VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.pay.id) { index, group in
                VStack(spacing: 0) {
                    timelineChunk(for: group)
                        .padding(.top, index == 0 ? 0 : TimelineSpacing.chunkTopGap)
                        .padding(.bottom, TimelineSpacing.balanceBottomGap)

                    if group.pay.id != groups.last?.pay.id {
                        Rectangle()
                            .fill(.black.opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.bottom, TimelineSpacing.dividerBottomGap)
                    }
                }
            }
        }
    }

    private func timelineChunk(for group: TimelineGroup) -> some View {
        let showEndingBalance = shouldShowEndingBalance(for: group)

        return VStack(spacing: 0) {
            rowGrid {
                Text(group.pay.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.floatText)
                    .lineLimit(1)
                    .layoutPriority(1)
            } date: {
                dateText(group.pay.date)
            } amount: {
                payAmountText(for: group)
            }
            .padding(.bottom, group.bills.isEmpty && !showEndingBalance ? 0 : TimelineSpacing.rowGap)

            ForEach(Array(group.bills.enumerated()), id: \.element.id) { index, bill in
                rowGrid {
                    HStack(spacing: 4) {
                        Text(bill.label)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.floatText)
                            .lineLimit(1)
                        if bill.amount == 0 {
                            Text("!")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.red)
                        }
                    }
                } date: {
                    dateText(bill.date)
                } amount: {
                    Text("-\(money(bill.amount))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.floatTextSubtle)
                        .lineLimit(1)
                }
                .padding(.bottom, index == group.bills.count - 1 ? 0 : TimelineSpacing.rowGap)
            }

            if showEndingBalance {
                HStack {
                    Spacer()
                    Text(balanceText(group.balance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(group.balance >= 0 ? Color.floatAccent : Color.floatDanger)
                        .fixedSize()
                        .measureColumnWidth(AmountColumnWidthPreferenceKey.self)
                        .frame(width: amountColumnWidth, alignment: .trailing)
                }
                .padding(.top, TimelineSpacing.balanceTopGap)
            }
        }
    }

    private func metric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: label == "Goal" ? .trailing : .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private func rowGrid<Label: View, DateColumn: View, Amount: View>(
        @ViewBuilder label: () -> Label,
        @ViewBuilder date: () -> DateColumn,
        @ViewBuilder amount: () -> Amount
    ) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 0) {
            GridRow {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gridCellColumns(1)

                date()
                    .fixedSize()
                    .measureColumnWidth(DateColumnWidthPreferenceKey.self)
                    .frame(width: dateColumnWidth, alignment: .leading)

                amount()
                    .fixedSize()
                    .measureColumnWidth(AmountColumnWidthPreferenceKey.self)
                    .frame(width: amountColumnWidth, alignment: .trailing)
            }
        }
    }

    private func dateText(_ value: String) -> some View {
        Text(labelDate(value))
            .font(.system(size: 13))
            .foregroundStyle(Color.floatTextSubtle)
    }

    private func shouldShowEndingBalance(for group: TimelineGroup) -> Bool {
        group.pay.id != "starting-balance" || !group.bills.isEmpty
    }

    private func payAmountText(for group: TimelineGroup) -> some View {
        Text(group.pay.id == "starting-balance" ? balanceText(group.income) : incomeAmountText(for: group))
            .font(.system(size: 13, weight: group.pay.id == "starting-balance" ? .semibold : .regular))
            .foregroundStyle(group.pay.id == "starting-balance" ? Color.floatAccent : Color.floatTextSubtle)
    }

    private func incomeAmountText(for group: TimelineGroup) -> String {
        if group.pay.id == "starting-balance" {
            return money(group.income)
        }
        return signedMoney(group.income)
    }

    private func balanceText(_ amount: Double) -> String {
        amount < 0 ? "-\(money(abs(amount)))" : money(amount)
    }

    private func longDate(_ value: String) -> String {
        guard let date = Date.yyyyMMdd.date(from: value) else { return value }
        return date.formatted(.dateTime.month(.wide).day())
    }

    private func groupedEvents() -> [TimelineGroup] {
        let visibleEvents = events.filter { $0.label != "Confirmed balance" }
        let income = visibleEvents.filter { $0.type == .income }.sorted { $0.date < $1.date }
        let bills = visibleEvents.filter { $0.type == .bill }.sorted { $0.date < $1.date }
        var running = account.currentBalance

        let firstIncomeDate = income.first?.date ?? "9999-12-31"
        let startingBills = bills.filter { $0.date < firstIncomeDate }
        running -= startingBills.reduce(0) { $0 + $1.amount }

        let startingGroup = TimelineGroup(
            pay: CashEvent(
                id: "starting-balance",
                type: .income,
                label: account.balanceIsConfirmed ? "Confirmed balance" : "Current balance",
                amount: account.currentBalance,
                date: account.lastConfirmedDate ?? Date.todayString
            ),
            bills: startingBills,
            income: account.currentBalance,
            balance: running
        )

        let incomeGroups = income.enumerated().map { index, pay in
            let end = income.indices.contains(index + 1) ? income[index + 1].date : "9999-12-31"
            let groupBills = bills.filter { $0.date >= pay.date && $0.date < end }
            let spent = groupBills.reduce(0) { $0 + $1.amount }
            running += pay.amount - spent
            return TimelineGroup(pay: pay, bills: groupBills, income: pay.amount, balance: running)
        }

        return [startingGroup] + incomeGroups
    }
}

private struct TimelineGroup {
    let pay: CashEvent
    let bills: [CashEvent]
    let income: Double
    let balance: Double
}

private struct DateColumnWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AmountColumnWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ColumnWidthReader<Key: PreferenceKey>: ViewModifier where Key.Value == CGFloat {
    let key: Key.Type

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(key: key, value: proxy.size.width)
            }
        }
    }
}

private extension View {
    func measureColumnWidth<Key: PreferenceKey>(_ key: Key.Type) -> some View where Key.Value == CGFloat {
        modifier(ColumnWidthReader(key: key))
    }
}
