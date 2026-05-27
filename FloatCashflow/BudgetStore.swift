import Foundation
import WidgetKit

@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var budget: FloatBudget
    @Published private(set) var isDemoMode: Bool
    @Published private(set) var lastBackupExportDate: Date?
    @Published private(set) var lastBackupImportDate: Date?
    @Published private(set) var needsLegacyWebMigration: Bool
    @Published private(set) var selectedPalette: AccountPalette

    private let storageURL: URL
    private let defaults = UserDefaults.standard

    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = directory.appendingPathComponent("float-budget-v1.json")
        isDemoMode = defaults.bool(forKey: AppStorageKey.demoMode)
        lastBackupExportDate = defaults.object(forKey: AppStorageKey.lastBackupExportDate) as? Date
        lastBackupImportDate = defaults.object(forKey: AppStorageKey.lastBackupImportDate) as? Date
        needsLegacyWebMigration = false
        selectedPalette = AccountPalette.find(defaults.string(forKey: AppStorageKey.accountPaletteId) ?? AccountPalette.fallback.id)

        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(FloatBudget.self, from: data) {
            budget = decoded
            applyDueReserveTransfers()
        } else if let legacyBudget = LegacyBudgetMigration.budgetFromContainerFiles() {
            budget = legacyBudget
            if budget.activeAccount == nil {
                budget.activeAccountId = budget.accounts[0].id
            }
            markRealBudget()
            defaults.set(true, forKey: AppStorageKey.legacyMigrationAttempted)
            save()
        } else {
            needsLegacyWebMigration = !defaults.bool(forKey: AppStorageKey.legacyMigrationAttempted)
            if defaults.bool(forKey: AppStorageKey.onboardingComplete) || defaults.bool(forKey: AppStorageKey.demoWasEnded) {
                budget = .blank
                isDemoMode = false
            } else {
                budget = DemoBudget.make()
                isDemoMode = true
                defaults.set(true, forKey: AppStorageKey.demoMode)
            }

            if !needsLegacyWebMigration {
                save()
            }
        }
        updateWidgetSnapshot()
    }

    var activeAccount: FloatAccount {
        budget.activeAccount ?? FloatBudget.blank.accounts[0]
    }

    func setActiveAccount(_ id: String) {
        budget.activeAccountId = id
        save()
    }

    func noteBackupExported() {
        lastBackupExportDate = Date()
        defaults.set(lastBackupExportDate, forKey: AppStorageKey.lastBackupExportDate)
    }

    func addAccount(name: String, startingBalance: Double) {
        let id = "acct-\(Date().timeIntervalSince1970)"
        let account = FloatAccount(
            id: id,
            name: name,
            color: selectedPalette.background(for: budget.accounts.count),
            currentBalance: startingBalance,
            reserveBalance: 0,
            reserveGoal: 0,
            lastConfirmedDate: Date.todayString,
            bills: [],
            income: [],
            paidEarlyBills: [],
            appliedReserveTransfers: [],
            balanceIsConfirmed: true
        )

        budget.accounts.append(account)
        budget.activeAccountId = id
        save()
    }

    func selectPalette(_ palette: AccountPalette) {
        selectedPalette = palette
        defaults.set(palette.id, forKey: AppStorageKey.accountPaletteId)
        for index in budget.accounts.indices {
            budget.accounts[index].color = palette.background(for: index)
        }
        save()
    }

    func renameAccount(id: String, name: String) {
        guard let index = budget.accounts.firstIndex(where: { $0.id == id }) else { return }
        budget.accounts[index].name = name
        save()
    }

    func updateAccount(id: String, name: String, cashBalance: Double) {
        guard let index = budget.accounts.firstIndex(where: { $0.id == id }) else { return }
        budget.accounts[index].name = name
        budget.accounts[index].currentBalance = cashBalance
        budget.accounts[index].lastConfirmedDate = Date.todayString
        budget.accounts[index].balanceIsConfirmed = true
        budget.accounts[index].income.removeAll { $0.label == "Confirmed balance" }
        save()
    }

    func deleteAccount(id: String) {
        guard budget.accounts.count > 1 else { return }

        budget.accounts.removeAll { $0.id == id }
        if budget.activeAccountId == id {
            budget.activeAccountId = budget.accounts[0].id
        }
        save()
    }

    func updateActiveAccount(_ update: (inout FloatAccount) -> Void) {
        guard let index = budget.accounts.firstIndex(where: { $0.id == budget.activeAccountId }) else { return }
        update(&budget.accounts[index])
        save()
    }

    func confirmBalance(_ amount: Double) {
        updateActiveAccount {
            $0.currentBalance = amount
            $0.lastConfirmedDate = Date.todayString
            $0.balanceIsConfirmed = true
            $0.income.removeAll { $0.label == "Confirmed balance" }
        }
    }

    func updateReserve(balance: Double) {
        updateActiveAccount {
            $0.reserveBalance = balance
            $0.appliedReserveTransfers = $0.appliedReserveTransfers
        }
    }

    func updateReserveGoal(_ goal: Double) {
        updateActiveAccount {
            $0.reserveGoal = goal
        }
    }

    func addBill(name: String, amount: Double, startDate: Date, frequency: Frequency) {
        guard let activeIndex = activeAccountIndex else { return }

        let stamp = timestamp()
        let transferId = "transfer-\(stamp)"
        let targetIndex = transferToAccountIndex(named: name).flatMap { $0 == activeIndex ? nil : $0 }
        let linkedTransferId = targetIndex == nil ? nil : transferId

        budget.accounts[activeIndex].bills.append(BudgetBill(
            id: "bill-\(stamp)",
            name: name,
            amount: amount,
            startDate: startDate.ymdString,
            frequency: frequency,
            active: true,
            linkedTransferId: linkedTransferId
        ))

        if let targetIndex {
            budget.accounts[targetIndex].income.append(BudgetIncome(
                id: "income-transfer-\(stamp)",
                label: "Transfer from \(budget.accounts[activeIndex].name)",
                amount: amount,
                startDate: startDate.ymdString,
                frequency: frequency,
                active: true,
                linkedTransferId: transferId
            ))
        }

        save()
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
        guard let activeIndex = activeAccountIndex else { return }

        let targetName = normalizedName(name)
        let debtDetails = BudgetDebtDetails(
            startingBalance: startingBalance,
            currentPrincipal: currentPrincipal,
            accruedInterest: accruedInterest,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: interestRateAPR,
            minimumPayment: minimumPayment
        )

        if let matchingBillIndex = budget.accounts[activeIndex].bills.firstIndex(where: {
            $0.debtDetails != nil && normalizedName($0.name) == targetName
        }) {
            budget.accounts[activeIndex].bills[matchingBillIndex].name = name
            budget.accounts[activeIndex].bills[matchingBillIndex].amount = plannedMonthlyPayment
            budget.accounts[activeIndex].bills[matchingBillIndex].startDate = nextPaymentDate.ymdString
            budget.accounts[activeIndex].bills[matchingBillIndex].frequency = .monthly
            budget.accounts[activeIndex].bills[matchingBillIndex].debtDetails = debtDetails
            save()
            return
        }

        let stamp = timestamp()
        budget.accounts[activeIndex].bills.append(BudgetBill(
            id: "debt-\(stamp)",
            name: name,
            amount: plannedMonthlyPayment,
            startDate: nextPaymentDate.ymdString,
            frequency: .monthly,
            active: true,
            linkedTransferId: nil,
            debtDetails: debtDetails
        ))

        save()
    }

    func addIncome(label: String, amount: Double, startDate: Date, frequency: Frequency) {
        guard let activeIndex = activeAccountIndex else { return }

        let stamp = timestamp()
        let transferId = "transfer-\(stamp)"
        let sourceIndex = transferFromAccountIndex(label: label).flatMap { $0 == activeIndex ? nil : $0 }
        let linkedTransferId = sourceIndex == nil ? nil : transferId

        budget.accounts[activeIndex].income.append(BudgetIncome(
            id: "income-\(stamp)",
            label: label,
            amount: amount,
            startDate: startDate.ymdString,
            frequency: frequency,
            active: true,
            linkedTransferId: linkedTransferId
        ))

        if let sourceIndex {
            budget.accounts[sourceIndex].bills.append(BudgetBill(
                id: "bill-transfer-\(stamp)",
                name: "Transfer to \(budget.accounts[activeIndex].name)",
                amount: amount,
                startDate: startDate.ymdString,
                frequency: frequency,
                active: true,
                linkedTransferId: transferId
            ))
        }

        save()
    }

    func payBillEarly(_ bill: BudgetBill) {
        updateActiveAccount {
            let originalDate = BudgetMath.nextRecurringDate(
                startDate: bill.startDate,
                frequency: bill.frequency,
                currentDate: Date.todayString
            )

            $0.currentBalance -= bill.amount
            $0.balanceIsConfirmed = false
            $0.paidEarlyBills.append(PaidEarlyBill(
                id: "early-\(Date().timeIntervalSince1970)",
                billId: bill.id,
                originalDate: originalDate,
                paidDate: Date.todayString,
                amount: bill.amount
            ))
        }
    }

    func deleteBill(_ bill: BudgetBill) {
        for index in budget.accounts.indices {
            budget.accounts[index].bills.removeAll { $0.id == bill.id }
            if let linkedTransferId = bill.linkedTransferId {
                budget.accounts[index].income.removeAll { $0.linkedTransferId == linkedTransferId }
            }
        }
        save()
    }

    func updateBill(_ bill: BudgetBill, name: String, amount: Double, startDate: Date, frequency: Frequency) {
        let wasTransfer = bill.name.lowercased().hasPrefix("transfer to ")
        let willBeTransfer = name.lowercased().hasPrefix("transfer to ")
        let linkedTransferId = bill.linkedTransferId

        if wasTransfer, !willBeTransfer, let linkedTransferId {
            for accountIndex in budget.accounts.indices {
                if let billIndex = budget.accounts[accountIndex].bills.firstIndex(where: { $0.id == bill.id }) {
                    budget.accounts[accountIndex].bills[billIndex].name = name
                    budget.accounts[accountIndex].bills[billIndex].amount = amount
                    budget.accounts[accountIndex].bills[billIndex].startDate = startDate.ymdString
                    budget.accounts[accountIndex].bills[billIndex].frequency = frequency
                    budget.accounts[accountIndex].bills[billIndex].linkedTransferId = nil
                }
                budget.accounts[accountIndex].income.removeAll { $0.linkedTransferId == linkedTransferId }
            }
            save()
            return
        }

        for accountIndex in budget.accounts.indices {
            if let billIndex = budget.accounts[accountIndex].bills.firstIndex(where: { $0.id == bill.id }) {
                budget.accounts[accountIndex].bills[billIndex].name = name
                budget.accounts[accountIndex].bills[billIndex].amount = amount
                budget.accounts[accountIndex].bills[billIndex].startDate = startDate.ymdString
                budget.accounts[accountIndex].bills[billIndex].frequency = frequency
            }

            if let linkedTransferId {
                for incomeIndex in budget.accounts[accountIndex].income.indices where budget.accounts[accountIndex].income[incomeIndex].linkedTransferId == linkedTransferId {
                    budget.accounts[accountIndex].income[incomeIndex].amount = amount
                    budget.accounts[accountIndex].income[incomeIndex].startDate = startDate.ymdString
                    if frequency != .annual {
                        budget.accounts[accountIndex].income[incomeIndex].frequency = frequency
                    }
                }
            }
        }
        save()
    }

    func updateDebt(
        _ bill: BudgetBill,
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
        for accountIndex in budget.accounts.indices {
            if let billIndex = budget.accounts[accountIndex].bills.firstIndex(where: { $0.id == bill.id }) {
                budget.accounts[accountIndex].bills[billIndex].name = name
                budget.accounts[accountIndex].bills[billIndex].amount = plannedMonthlyPayment
                budget.accounts[accountIndex].bills[billIndex].startDate = nextPaymentDate.ymdString
                budget.accounts[accountIndex].bills[billIndex].frequency = .monthly
                budget.accounts[accountIndex].bills[billIndex].debtDetails = BudgetDebtDetails(
                    startingBalance: startingBalance,
                    currentPrincipal: currentPrincipal,
                    accruedInterest: accruedInterest,
                    balanceDate: balanceDate.ymdString,
                    interestRateAPR: interestRateAPR,
                    minimumPayment: minimumPayment
                )
            }
        }

        save()
    }

    func updateDebtSnapshotFromTool(
        matchingDebtId: String? = nil,
        matchingName: String? = nil,
        name: String,
        startingBalance: Double,
        currentPrincipal: Double,
        accruedInterest: Double,
        balanceDate: Date,
        interestRateAPR: Double,
        minimumPayment: Double,
        nextPaymentDate: Date
    ) {
        guard let match = debtBillIndex(matchingDebtId: matchingDebtId, matchingName: matchingName ?? name) else {
            return
        }

        budget.accounts[match.accountIndex].bills[match.billIndex].name = name
        budget.accounts[match.accountIndex].bills[match.billIndex].startDate = nextPaymentDate.ymdString
        budget.accounts[match.accountIndex].bills[match.billIndex].debtDetails = BudgetDebtDetails(
            startingBalance: startingBalance,
            currentPrincipal: currentPrincipal,
            accruedInterest: accruedInterest,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: interestRateAPR,
            minimumPayment: minimumPayment
        )
        save()
    }

    func deleteDebtFromTool(_ debt: DebtPayoffItem) {
        guard let match = debtBillIndex(matchingDebtId: debt.id, matchingName: debt.name) else { return }
        budget.accounts[match.accountIndex].bills.remove(at: match.billIndex)
        save()
    }

    func deleteIncome(_ income: BudgetIncome) {
        for index in budget.accounts.indices {
            budget.accounts[index].income.removeAll { $0.id == income.id }
            if let linkedTransferId = income.linkedTransferId {
                budget.accounts[index].bills.removeAll { $0.linkedTransferId == linkedTransferId }
            }
        }
        save()
    }

    func updateIncome(_ income: BudgetIncome, label: String, amount: Double, startDate: Date, frequency: Frequency) {
        let wasTransfer = income.label.lowercased().hasPrefix("transfer from ")
        let willBeTransfer = label.lowercased().hasPrefix("transfer from ")
        let linkedTransferId = income.linkedTransferId

        if wasTransfer, !willBeTransfer, let linkedTransferId {
            for accountIndex in budget.accounts.indices {
                if let incomeIndex = budget.accounts[accountIndex].income.firstIndex(where: { $0.id == income.id }) {
                    budget.accounts[accountIndex].income[incomeIndex].label = label
                    budget.accounts[accountIndex].income[incomeIndex].amount = amount
                    budget.accounts[accountIndex].income[incomeIndex].startDate = startDate.ymdString
                    budget.accounts[accountIndex].income[incomeIndex].frequency = frequency
                    budget.accounts[accountIndex].income[incomeIndex].linkedTransferId = nil
                }
                budget.accounts[accountIndex].bills.removeAll { $0.linkedTransferId == linkedTransferId }
            }
            save()
            return
        }

        for accountIndex in budget.accounts.indices {
            if let incomeIndex = budget.accounts[accountIndex].income.firstIndex(where: { $0.id == income.id }) {
                budget.accounts[accountIndex].income[incomeIndex].label = label
                budget.accounts[accountIndex].income[incomeIndex].amount = amount
                budget.accounts[accountIndex].income[incomeIndex].startDate = startDate.ymdString
                budget.accounts[accountIndex].income[incomeIndex].frequency = frequency
            }

            if let linkedTransferId {
                for billIndex in budget.accounts[accountIndex].bills.indices where budget.accounts[accountIndex].bills[billIndex].linkedTransferId == linkedTransferId {
                    budget.accounts[accountIndex].bills[billIndex].amount = amount
                    budget.accounts[accountIndex].bills[billIndex].startDate = startDate.ymdString
                    budget.accounts[accountIndex].bills[billIndex].frequency = frequency
                }
            }
        }
        save()
    }

    func importBackup(from url: URL) throws {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        try importBackup(data: data)
    }

    func importBackup(data: Data) throws {
        let imported = try JSONDecoder().decode(FloatBudget.self, from: data)
        guard imported.version == 1, !imported.accounts.isEmpty else {
            throw ImportError.invalidBackup
        }

        budget = imported
        if budget.activeAccount == nil {
            budget.activeAccountId = budget.accounts[0].id
        }
        markRealBudget()
        lastBackupImportDate = Date()
        defaults.set(lastBackupImportDate, forKey: AppStorageKey.lastBackupImportDate)
        applyDueReserveTransfers()
        save()
    }

    func finishOnboarding() {
        defaults.set(true, forKey: AppStorageKey.onboardingComplete)
    }

    func startOwnBudget() {
        budget = .newUserBlank
        defaults.set(false, forKey: AppStorageKey.firstSetupComplete)
        markRealBudget()
        save()
    }

    func completeLegacyWebMigration(rawValue: String?) {
        guard needsLegacyWebMigration else { return }

        needsLegacyWebMigration = false
        defaults.set(true, forKey: AppStorageKey.legacyMigrationAttempted)

        guard let legacyBudget = LegacyBudgetMigration.budgetFromLocalStorageValue(rawValue) else {
            save()
            return
        }

        budget = legacyBudget
        if budget.activeAccount == nil {
            budget.activeAccountId = budget.accounts[0].id
        }
        markRealBudget()
        save()
    }

    private func markRealBudget() {
        isDemoMode = false
        defaults.set(false, forKey: AppStorageKey.demoMode)
        defaults.set(true, forKey: AppStorageKey.demoWasEnded)
        defaults.set(true, forKey: AppStorageKey.onboardingComplete)
    }

    private func save() {
        applyDueReserveTransfers()
        updateWidgetSnapshot()
        guard let data = try? JSONEncoder().encode(budget) else { return }
        try? data.write(to: storageURL, options: [.atomic])
    }

    private func updateWidgetSnapshot() {
        FloatWidgetSnapshot.make(from: budget).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    enum ImportError: LocalizedError {
        case invalidBackup

        var errorDescription: String? {
            "This backup file is not a valid Float backup."
        }
    }

    private var activeAccountIndex: Int? {
        budget.accounts.firstIndex { $0.id == budget.activeAccountId }
    }

    private func timestamp() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000))
    }

    private func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func debtBillIndex(matchingDebtId: String?, matchingName: String?) -> (accountIndex: Int, billIndex: Int)? {
        if let billId = budgetBillId(fromPayoffDebtId: matchingDebtId) {
            for accountIndex in budget.accounts.indices {
                if let billIndex = budget.accounts[accountIndex].bills.firstIndex(where: {
                    $0.id == billId && $0.debtDetails != nil
                }) {
                    return (accountIndex, billIndex)
                }
            }
        }

        guard let activeIndex = activeAccountIndex,
              let matchingName else {
            return nil
        }

        let targetName = normalizedName(matchingName)
        guard let billIndex = budget.accounts[activeIndex].bills.firstIndex(where: {
            $0.debtDetails != nil && normalizedName($0.name) == targetName
        }) else {
            return nil
        }

        return (activeIndex, billIndex)
    }

    private func budgetBillId(fromPayoffDebtId debtId: String?) -> String? {
        guard let debtId, debtId.hasPrefix("budget-") else { return nil }
        return String(debtId.dropFirst("budget-".count))
    }

    private func transferToAccountIndex(named billName: String) -> Int? {
        let normalized = billName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("transfer to ") else { return nil }

        let targetName = normalized
            .replacingOccurrences(of: "transfer to ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard targetName != "reserve" else { return nil }
        return budget.accounts.firstIndex { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == targetName }
    }

    private func transferFromAccountIndex(label: String) -> Int? {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("transfer from ") else { return nil }

        let sourceName = normalized
            .replacingOccurrences(of: "transfer from ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return budget.accounts.firstIndex { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == sourceName }
    }

    private func applyDueReserveTransfers() {
        for index in budget.accounts.indices {
            let dueTransfers = BudgetMath.dueReserveTransfers(account: budget.accounts[index])
            guard !dueTransfers.isEmpty else { continue }

            budget.accounts[index].reserveBalance += dueTransfers.reduce(0) { $0 + $1.amount }
            budget.accounts[index].appliedReserveTransfers.append(contentsOf: dueTransfers.map(\.id))
        }
    }
}

enum AppStorageKey {
    static let onboardingComplete = "float:onboardingComplete"
    static let demoMode = "float:demoMode"
    static let demoWasEnded = "float:demoModeEnded"
    static let lastBackupExportDate = "float:lastBackupExportDate"
    static let lastBackupImportDate = "float:lastBackupImportDate"
    static let legacyMigrationAttempted = "float:legacyMigrationAttempted"
    static let accountPaletteId = "float:accountPaletteId"
    static let appLockEnabled = "float:appLockEnabled"
    static let appLockPasscodeHash = "float:appLockPasscodeHash"
    static let appLockPasscodeSalt = "float:appLockPasscodeSalt"
    static let settingsGuidanceVisible = "float:settingsGuidanceVisible"
    static let firstSetupComplete = "float:firstSetupComplete"
}
