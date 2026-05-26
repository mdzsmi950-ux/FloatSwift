import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: BudgetStore
    var startOwnBudget: () -> Void

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

    private let dateColumnWidth: CGFloat = 48
    private let amountColumnWidth: CGFloat = 116

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    header
                    reserveCard
                    timeline
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 96)
                .frame(minHeight: proxy.size.height + 1, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let sinkingDate {
                    Text("Sinking \(longDate(sinkingDate))!")
                    Text("Cut Back Spending Now!")
                } else {
                    Text("Floating")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(sinkingDate == nil ? Color.floatTextSubtle : Color.floatWarning)

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

            Button {
                cycleAccount()
            } label: {
                HStack(spacing: 6) {
                    Text(account.name)
                    if store.budget.accounts.count > 1 {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.floatText.opacity(0.55))
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.floatText)
        }
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
        .background(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(groupedEvents().enumerated()), id: \.element.pay.id) { index, group in
                VStack(spacing: 0) {
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
                    .padding(.bottom, group.bills.isEmpty ? 0 : 4)

                    ForEach(group.bills) { bill in
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
                        .padding(.vertical, 4)
                    }

                    if group.pay.id != "starting-balance" {
                        HStack {
                            Spacer()
                            Text(balanceText(group.balance))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(group.balance >= 0 ? Color.floatAccent : Color.floatDanger)
                                .frame(width: amountColumnWidth, alignment: .trailing)
                        }
                        .padding(.top, group.bills.isEmpty ? 2 : 3)
                        .padding(.bottom, 7)
                    }
                }
                .padding(.top, index == 0 ? 0 : 8)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    if group.pay.id != groupedEvents().last?.pay.id {
                        Rectangle()
                            .fill(.black.opacity(0.1))
                            .frame(height: 0.5)
                    }
                }
                .padding(.bottom, 10)
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
                    .frame(width: dateColumnWidth, alignment: .leading)

                amount()
                    .frame(width: amountColumnWidth, alignment: .trailing)
            }
        }
    }

    private func dateText(_ value: String) -> some View {
        Text(labelDate(value))
            .font(.system(size: 13))
            .foregroundStyle(Color.floatTextSubtle)
    }

    private func payAmountText(for group: (pay: CashEvent, bills: [CashEvent], income: Double, balance: Double)) -> some View {
        Text(group.pay.id == "starting-balance" ? balanceText(group.income) : incomeAmountText(for: group))
            .font(.system(size: 13, weight: group.pay.id == "starting-balance" ? .semibold : .regular))
            .foregroundStyle(group.pay.id == "starting-balance" ? Color.floatAccent : Color.floatTextSubtle)
    }

    private func incomeAmountText(for group: (pay: CashEvent, bills: [CashEvent], income: Double, balance: Double)) -> String {
        if group.pay.id == "starting-balance" {
            return money(group.income)
        }
        return signedMoney(group.income)
    }

    private func balanceText(_ amount: Double) -> String {
        amount < 0 ? "-\(money(abs(amount)))" : money(amount)
    }

    private func cycleAccount() {
        guard store.budget.accounts.count > 1,
              let index = store.budget.accounts.firstIndex(where: { $0.id == account.id }) else { return }
        let next = store.budget.accounts[(index + 1) % store.budget.accounts.count]
        store.setActiveAccount(next.id)
    }

    private func longDate(_ value: String) -> String {
        guard let date = Date.yyyyMMdd.date(from: value) else { return value }
        return date.formatted(.dateTime.month(.wide).day())
    }

    private func groupedEvents() -> [(pay: CashEvent, bills: [CashEvent], income: Double, balance: Double)] {
        let visibleEvents = events.filter { $0.label != "Confirmed balance" }
        let income = visibleEvents.filter { $0.type == .income }.sorted { $0.date < $1.date }
        let bills = visibleEvents.filter { $0.type == .bill }.sorted { $0.date < $1.date }
        var running = account.currentBalance

        let firstIncomeDate = income.first?.date ?? "9999-12-31"
        let startingBills = bills.filter { $0.date < firstIncomeDate }
        running -= startingBills.reduce(0) { $0 + $1.amount }

        let startingGroup = (
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
            return (pay: pay, bills: groupBills, income: pay.amount, balance: running)
        }

        return [startingGroup] + incomeGroups
    }
}
