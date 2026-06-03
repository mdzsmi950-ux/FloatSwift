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
            cleanWidgetAccountSelection()
        } else if let legacyBudget = LegacyBudgetMigration.budgetFromContainerFiles() {
            budget = legacyBudget
            if budget.activeAccount == nil {
                budget.activeAccountId = budget.accounts[0].id
            }
            cleanWidgetAccountSelection()
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

    func setWidgetAccount(id: String?) {
        if let id, budget.accounts.contains(where: { $0.id == id }) {
            budget.widgetAccountId = id
        } else {
            budget.widgetAccountId = nil
        }
        save()
    }

    func deleteAccount(id: String) {
        guard budget.accounts.count > 1 else { return }

        budget.accounts.removeAll { $0.id == id }
        if budget.activeAccountId == id {
            budget.activeAccountId = budget.accounts[0].id
        }
        if budget.widgetAccountId == id {
            budget.widgetAccountId = nil
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
        }
    }

    func updateReserveGoal(_ goal: Double) {
        updateActiveAccount {
            $0.reserveGoal = goal
        }
    }

    func addBill(name: String, amount: Double, startDate: Date, frequency: Frequency, debtDetails: BudgetDebtDetails? = nil) {
        guard let activeIndex = activeAccountIndex else { return }

        let stamp = timestamp()

        budget.accounts[activeIndex].bills.append(BudgetBill(
            id: "bill-\(stamp)",
            name: name,
            amount: amount,
            startDate: startDate.ymdString,
            frequency: frequency,
            active: true,
            debtDetails: debtDetails
        ))

        save()
    }

    func addIncome(label: String, amount: Double, startDate: Date, frequency: Frequency) {
        guard let activeIndex = activeAccountIndex else { return }

        let stamp = timestamp()

        budget.accounts[activeIndex].income.append(BudgetIncome(
            id: "income-\(stamp)",
            label: label,
            amount: amount,
            startDate: startDate.ymdString,
            frequency: frequency,
            active: true
        ))

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
        }
        save()
    }

    func updateBill(_ bill: BudgetBill, name: String, amount: Double, startDate: Date, frequency: Frequency, debtDetails: BudgetDebtDetails? = nil) {
        for accountIndex in budget.accounts.indices {
            if let billIndex = budget.accounts[accountIndex].bills.firstIndex(where: { $0.id == bill.id }) {
                budget.accounts[accountIndex].bills[billIndex].name = name
                budget.accounts[accountIndex].bills[billIndex].amount = amount
                budget.accounts[accountIndex].bills[billIndex].startDate = startDate.ymdString
                budget.accounts[accountIndex].bills[billIndex].frequency = frequency
                budget.accounts[accountIndex].bills[billIndex].debtDetails = debtDetails
            }
        }
        save()
    }

    func deleteIncome(_ income: BudgetIncome) {
        for index in budget.accounts.indices {
            budget.accounts[index].income.removeAll { $0.id == income.id }
        }
        save()
    }

    func updateIncome(_ income: BudgetIncome, label: String, amount: Double, startDate: Date, frequency: Frequency) {
        for accountIndex in budget.accounts.indices {
            if let incomeIndex = budget.accounts[accountIndex].income.firstIndex(where: { $0.id == income.id }) {
                budget.accounts[accountIndex].income[incomeIndex].label = label
                budget.accounts[accountIndex].income[incomeIndex].amount = amount
                budget.accounts[accountIndex].income[incomeIndex].startDate = startDate.ymdString
                budget.accounts[accountIndex].income[incomeIndex].frequency = frequency
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
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(FloatBackupPayload.self, from: data) {
            try replaceBudget(with: payload.budget)
            return
        }

        let imported = try decoder.decode(FloatBudget.self, from: data)
        try replaceBudget(with: imported)
    }

    private func replaceBudget(with imported: FloatBudget) throws {
        guard imported.version == 1, !imported.accounts.isEmpty else {
            throw ImportError.invalidBackup
        }

        budget = imported
        if budget.activeAccount == nil {
            budget.activeAccountId = budget.accounts[0].id
        }
        cleanWidgetAccountSelection()
        markRealBudget()
        lastBackupImportDate = Date()
        defaults.set(lastBackupImportDate, forKey: AppStorageKey.lastBackupImportDate)
        save()
    }

    func finishOnboarding() {
        defaults.set(true, forKey: AppStorageKey.onboardingComplete)
    }

    func startOwnBudget() {
        budget = .newUserBlank
        defaults.set(false, forKey: AppStorageKey.firstAccountSetupComplete)
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
        cleanWidgetAccountSelection()
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
        cleanWidgetAccountSelection()
        updateWidgetSnapshot()
        guard let data = try? JSONEncoder().encode(budget) else { return }
        try? data.write(to: storageURL, options: [.atomic])
    }

    private func cleanWidgetAccountSelection() {
        guard let widgetAccountId = budget.widgetAccountId,
              budget.accounts.contains(where: { $0.id == widgetAccountId }) else {
            budget.widgetAccountId = nil
            return
        }
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
    static let firstAccountSetupComplete = "float:firstAccountSetupComplete"
}
