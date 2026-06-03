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
    @Published private(set) var lastSaveError: String?

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
        lastSaveError = nil

        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode(FloatBudget.self, from: data) {
            budget = decoded
            let repairedActiveAccount = repairActiveAccountSelection()
            cleanWidgetAccountSelection()
            if !budgetLooksLikeDemo(decoded) {
                markRealBudget()
            }
            if repairedActiveAccount {
                save()
            }
        } else if let legacyBudget = LegacyBudgetMigration.budgetFromContainerFiles() {
            budget = legacyBudget
            repairActiveAccountSelection()
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

    var shouldShowAutomaticOnboarding: Bool {
        isDemoMode && !defaults.bool(forKey: AppStorageKey.onboardingComplete)
    }

    func setActiveAccount(_ id: String) {
        guard budget.accounts.contains(where: { $0.id == id }) else { return }
        let previous = budget
        budget.activeAccountId = id
        commitMutation(previous)
    }

    func noteBackupExported() {
        lastBackupExportDate = Date()
        defaults.set(lastBackupExportDate, forKey: AppStorageKey.lastBackupExportDate)
    }

    func clearSaveError() {
        lastSaveError = nil
    }

    func addAccount(name: String, startingBalance: Double) {
        let previous = budget
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
        commitMutation(previous)
    }

    func selectPalette(_ palette: AccountPalette) {
        let previous = budget
        selectedPalette = palette
        defaults.set(palette.id, forKey: AppStorageKey.accountPaletteId)
        for index in budget.accounts.indices {
            budget.accounts[index].color = palette.background(for: index)
        }
        commitMutation(previous)
    }

    func renameAccount(id: String, name: String) {
        guard let index = budget.accounts.firstIndex(where: { $0.id == id }) else { return }
        let previous = budget
        budget.accounts[index].name = name
        commitMutation(previous)
    }

    func setWidgetAccount(id: String?) {
        let previous = budget
        if let id, budget.accounts.contains(where: { $0.id == id }) {
            budget.widgetAccountId = id
        } else {
            budget.widgetAccountId = nil
        }
        commitMutation(previous)
    }

    func deleteAccount(id: String) {
        guard budget.accounts.count > 1 else { return }

        let previous = budget
        budget.accounts.removeAll { $0.id == id }
        if budget.activeAccountId == id {
            budget.activeAccountId = budget.accounts[0].id
        }
        if budget.widgetAccountId == id {
            budget.widgetAccountId = nil
        }
        commitMutation(previous)
    }

    func updateActiveAccount(_ update: (inout FloatAccount) -> Void) {
        guard let index = budget.accounts.firstIndex(where: { $0.id == budget.activeAccountId }) else { return }
        let previous = budget
        update(&budget.accounts[index])
        commitMutation(previous)
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

        let previous = budget
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

        commitMutation(previous)
    }

    func addIncome(label: String, amount: Double, startDate: Date, frequency: Frequency) {
        guard let activeIndex = activeAccountIndex else { return }

        let previous = budget
        let stamp = timestamp()

        budget.accounts[activeIndex].income.append(BudgetIncome(
            id: "income-\(stamp)",
            label: label,
            amount: amount,
            startDate: startDate.ymdString,
            frequency: frequency,
            active: true
        ))

        commitMutation(previous)
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
        guard let activeIndex = activeAccountIndex else { return }
        let previous = budget
        budget.accounts[activeIndex].bills.removeAll { $0.id == bill.id }
        commitMutation(previous)
    }

    func updateBill(_ bill: BudgetBill, name: String, amount: Double, startDate: Date, frequency: Frequency, debtDetails: BudgetDebtDetails? = nil) {
        guard let activeIndex = activeAccountIndex,
              let billIndex = budget.accounts[activeIndex].bills.firstIndex(where: { $0.id == bill.id }) else { return }
        let previous = budget
        budget.accounts[activeIndex].bills[billIndex].name = name
        budget.accounts[activeIndex].bills[billIndex].amount = amount
        budget.accounts[activeIndex].bills[billIndex].startDate = startDate.ymdString
        budget.accounts[activeIndex].bills[billIndex].frequency = frequency
        budget.accounts[activeIndex].bills[billIndex].debtDetails = debtDetails
        commitMutation(previous)
    }

    func deleteIncome(_ income: BudgetIncome) {
        guard let activeIndex = activeAccountIndex else { return }
        let previous = budget
        budget.accounts[activeIndex].income.removeAll { $0.id == income.id }
        commitMutation(previous)
    }

    func updateIncome(_ income: BudgetIncome, label: String, amount: Double, startDate: Date, frequency: Frequency) {
        guard let activeIndex = activeAccountIndex,
              let incomeIndex = budget.accounts[activeIndex].income.firstIndex(where: { $0.id == income.id }) else { return }
        let previous = budget
        budget.accounts[activeIndex].income[incomeIndex].label = label
        budget.accounts[activeIndex].income[incomeIndex].amount = amount
        budget.accounts[activeIndex].income[incomeIndex].startDate = startDate.ymdString
        budget.accounts[activeIndex].income[incomeIndex].frequency = frequency
        commitMutation(previous)
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

        let previous = budget
        budget = imported
        repairActiveAccountSelection()
        cleanWidgetAccountSelection()
        markRealBudget()
        lastBackupImportDate = Date()
        defaults.set(lastBackupImportDate, forKey: AppStorageKey.lastBackupImportDate)
        if !save() {
            budget = previous
            throw ImportError.saveFailed
        }
    }

    func finishOnboarding() {
        defaults.set(true, forKey: AppStorageKey.onboardingComplete)
    }

    func startOwnBudget() {
        let previous = budget
        budget = .newUserBlank
        defaults.set(false, forKey: AppStorageKey.firstAccountSetupComplete)
        defaults.set(false, forKey: AppStorageKey.firstSetupComplete)
        markRealBudget()
        commitMutation(previous)
    }

    func completeLegacyWebMigration(rawValue: String?) {
        guard needsLegacyWebMigration else { return }

        needsLegacyWebMigration = false
        defaults.set(true, forKey: AppStorageKey.legacyMigrationAttempted)

        guard let legacyBudget = LegacyBudgetMigration.budgetFromLocalStorageValue(rawValue) else {
            save()
            return
        }

        let previous = budget
        budget = legacyBudget
        repairActiveAccountSelection()
        cleanWidgetAccountSelection()
        markRealBudget()
        commitMutation(previous)
    }

    private func markRealBudget() {
        isDemoMode = false
        defaults.set(false, forKey: AppStorageKey.demoMode)
        defaults.set(true, forKey: AppStorageKey.demoWasEnded)
        defaults.set(true, forKey: AppStorageKey.onboardingComplete)
    }

    private func budgetLooksLikeDemo(_ budget: FloatBudget) -> Bool {
        budget.accounts.contains { account in
            account.bills.contains { $0.id.contains("-demo-") } ||
                account.income.contains { $0.id.contains("-demo-") }
        }
    }

    @discardableResult
    private func save() -> Bool {
        cleanWidgetAccountSelection()
        guard let data = try? JSONEncoder().encode(budget) else {
            lastSaveError = "Float could not prepare your budget to save."
            return false
        }
        do {
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            lastSaveError = "Float could not save your latest change."
            return false
        }
        lastSaveError = nil
        updateWidgetSnapshot()
        return true
    }

    private func commitMutation(_ previous: FloatBudget) {
        if !save() {
            budget = previous
            cleanWidgetAccountSelection()
        }
    }

    @discardableResult
    private func repairActiveAccountSelection() -> Bool {
        guard !budget.accounts.isEmpty else { return false }
        if !budget.accounts.contains(where: { $0.id == budget.activeAccountId }) {
            budget.activeAccountId = budget.accounts[0].id
            return true
        }
        return false
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
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .invalidBackup:
                "This backup file is not a valid Float backup."
            case .saveFailed:
                "Float could not save the imported backup."
            }
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
