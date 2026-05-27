import Foundation

@MainActor
final class DebtPayoffStore: ObservableObject {
    @Published private(set) var ledger: DebtPayoffLedger

    private let storageURL: URL

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = directory.appendingPathComponent("debt-payoff-v1.json")

        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(DebtPayoffLedger.self, from: data) {
            ledger = decoded
        } else {
            ledger = DebtPayoffLedger()
        }
    }

    var summary: DebtPayoffSummary {
        DebtPayoffMath.summary(for: ledger.debts)
    }

    func syncFromBudget(_ budget: FloatBudget) {
        var changed = false
        var budgetDebtIds = Set<String>()

        for account in budget.accounts {
            for bill in account.bills {
                guard let details = bill.debtDetails else { continue }
                let itemId = budgetLinkedId(for: bill.id)
                budgetDebtIds.insert(itemId)
                let item = DebtPayoffItem(
                    id: itemId,
                    name: bill.name,
                    startingBalance: details.startingBalance,
                    currentPrincipal: details.currentPrincipal,
                    accruedInterest: details.accruedInterest,
                    balanceDate: details.balanceDate,
                    interestRateAPR: details.interestRateAPR,
                    minimumPayment: details.minimumPayment,
                    plannedMonthlyPayment: bill.amount,
                    nextPaymentDate: bill.startDate
                )

                if let index = ledger.debts.firstIndex(where: { $0.id == item.id }) {
                    ledger.debts[index] = item
                } else if let index = singleStandaloneDebtIndex(named: item.name) {
                    ledger.debts[index] = item
                } else {
                    ledger.debts.append(item)
                }
                changed = true
            }
        }

        let countBeforeCleanup = ledger.debts.count
        ledger.debts.removeAll { debt in
            isBudgetLinked(debt.id) && !budgetDebtIds.contains(debt.id)
        }
        changed = changed || ledger.debts.count != countBeforeCleanup

        if changed {
            save()
        }
    }

    func addDebt(
        name: String,
        startingBalance: Double,
        currentPrincipal: Double,
        accruedInterest: Double,
        balanceDate: Date,
        interestRateAPR: Double,
        minimumPayment: Double,
        plannedMonthlyPayment: Double,
        nextPaymentDate: Date
    ) {
        ledger.debts.append(DebtPayoffItem(
            id: "debt-\(Date().timeIntervalSince1970)",
            name: name,
            startingBalance: startingBalance,
            currentPrincipal: currentPrincipal,
            accruedInterest: accruedInterest,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: interestRateAPR,
            minimumPayment: minimumPayment,
            plannedMonthlyPayment: plannedMonthlyPayment,
            nextPaymentDate: nextPaymentDate.ymdString
        ))
        save()
    }

    func updateDebt(
        _ debt: DebtPayoffItem,
        name: String,
        startingBalance: Double,
        currentPrincipal: Double,
        accruedInterest: Double,
        balanceDate: Date,
        interestRateAPR: Double,
        minimumPayment: Double,
        plannedMonthlyPayment: Double,
        nextPaymentDate: Date
    ) {
        guard let index = ledger.debts.firstIndex(where: { $0.id == debt.id }) else { return }
        ledger.debts[index] = DebtPayoffItem(
            id: debt.id,
            name: name,
            startingBalance: startingBalance,
            currentPrincipal: currentPrincipal,
            accruedInterest: accruedInterest,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: interestRateAPR,
            minimumPayment: minimumPayment,
            plannedMonthlyPayment: plannedMonthlyPayment,
            nextPaymentDate: nextPaymentDate.ymdString
        )
        save()
    }

    func replaceLedger(_ ledger: DebtPayoffLedger) {
        self.ledger = ledger
        save()
    }

    func deleteDebt(_ debt: DebtPayoffItem) {
        ledger.debts.removeAll { $0.id == debt.id }
        save()
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(ledger)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            assertionFailure("Unable to save debt payoff ledger: \(error)")
        }
    }

    private func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func budgetLinkedId(for billId: String) -> String {
        "budget-\(billId)"
    }

    private func isBudgetLinked(_ debtId: String) -> Bool {
        debtId.hasPrefix("budget-")
    }

    private func singleStandaloneDebtIndex(named name: String) -> Int? {
        let matches = ledger.debts.indices.filter {
            !isBudgetLinked(ledger.debts[$0].id) &&
                normalizedName(ledger.debts[$0].name) == normalizedName(name)
        }

        return matches.count == 1 ? matches[0] : nil
    }
}
