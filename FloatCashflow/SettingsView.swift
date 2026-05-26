import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    var goToOverview: () -> Void
    var startOwnBudget: () -> Void
    @ObservedObject var privacyLock: PrivacyLockStore
    @StateObject private var debtPayoffStore = DebtPayoffStore()

    @State private var expandedSections = Set(SettingsSection.allCases)
    @State private var confirmBalanceText = ""
    @State private var reserveText = ""
    @State private var reserveGoalText = ""
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var exportDocument = BackupDocument()
    @State private var pendingImportData: Data?
    @State private var importMessage: String?
    @State private var activeSheet: SettingsSheet?
    @State private var passcodeFlow: PasscodeFlow?
    @State private var showDebtPayoff = false
    @AppStorage(AppStorageKey.settingsGuidanceVisible) private var showGuidance = true
    @AppStorage(AppStorageKey.firstSetupComplete) private var firstSetupComplete = false

    private enum Layout {
        static let sectionGap: CGFloat = 12
        static let cardContentGap: CGFloat = 10
        static let itemGap: CGFloat = 12
        static let titleToHelperGap: CGFloat = 4
        static let helperToControlGap: CGFloat = 8
        static let rowVerticalPadding: CGFloat = 6
    }

    private var account: FloatAccount {
        store.activeAccount
    }

    private var backupStatusText: String {
        if let lastExport = store.lastBackupExportDate {
            return "Last export: \(relativeBackupDate(lastExport))"
        }

        if let lastImport = store.lastBackupImportDate {
            return "Last import: \(relativeBackupDate(lastImport))"
        }

        return "No backup exported yet."
    }

    private var backupStatusIsReminder: Bool {
        guard let lastExport = store.lastBackupExportDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastExport, to: Date()).day ?? 0
        return days >= 14
    }

    private var reserveBalancePlaceholder: String {
        account.reserveBalance == 0 ? "0.00" : money(account.reserveBalance)
    }

    private var confirmBalancePlaceholder: String {
        account.currentBalance == 0 ? "0.00" : money(account.currentBalance)
    }

    private var reserveGoalPlaceholder: String {
        account.reserveGoal == 0 ? "0.00" : money(account.reserveGoal)
    }

    private var setupStep: SetupStep? {
        guard !store.isDemoMode, !firstSetupComplete else { return nil }
        guard UserDefaults.standard.object(forKey: AppStorageKey.firstSetupComplete) != nil else { return nil }

        if !account.balanceIsConfirmed {
            return .balance
        }

        if account.income.filter({ $0.label != "Confirmed balance" }).isEmpty {
            return .income
        }

        if account.bills.isEmpty {
            return .obligation
        }

        return .overview
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: Layout.sectionGap) {
                    setupGuide
                    accountsSection
                    balanceSection
                    incomeSection
                    billsSection
                    debtsSection
                    reserveSection
                    generalSettingsSection
                    toolsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 146)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.always)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    pendingImportData = try readImportData(from: url)
                } catch {
                    importMessage = "This backup file could not be read."
                }
            case .failure:
                importMessage = "Import canceled."
            }
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                store.noteBackupExported()
                importMessage = "Backup exported."
            case .failure:
                importMessage = "Export failed."
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newBill:
                BillEditor(accountColor: account.color) { name, amount, date, frequency in
                    store.addBill(name: name, amount: amount, startDate: date, frequency: frequency)
                }
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.visible)
            case .editBill(let bill):
                BillEditor(accountColor: account.color, bill: bill) { name, amount, date, frequency in
                    store.updateBill(bill, name: name, amount: amount, startDate: date, frequency: frequency)
                } onDelete: {
                    store.deleteBill(bill)
                } onPaidEarly: {
                    store.payBillEarly(bill)
                }
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
            case .newDebt:
                DebtBillEditor(accountColor: account.color) { name, starting, principal, accrued, balanceDate, apr, minimum, monthly, paymentDate in
                    store.addDebt(
                        name: name,
                        startingBalance: starting,
                        currentPrincipal: principal,
                        accruedInterest: accrued,
                        balanceDate: balanceDate,
                        interestRateAPR: apr,
                        minimumPayment: minimum,
                        plannedMonthlyPayment: monthly,
                        nextPaymentDate: paymentDate
                    )
                    debtPayoffStore.syncFromBudget(store.budget)
                }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
            case .editDebt(let bill):
                DebtBillEditor(accountColor: account.color, bill: bill) { name, starting, principal, accrued, balanceDate, apr, minimum, monthly, paymentDate in
                    store.updateDebt(
                        bill,
                        name: name,
                        startingBalance: starting,
                        currentPrincipal: principal,
                        accruedInterest: accrued,
                        balanceDate: balanceDate,
                        interestRateAPR: apr,
                        minimumPayment: minimum,
                        plannedMonthlyPayment: monthly,
                        nextPaymentDate: paymentDate
                    )
                    debtPayoffStore.syncFromBudget(store.budget)
                } onDelete: {
                    store.deleteBill(bill)
                }
                .presentationDetents([.fraction(0.9), .large])
                .presentationDragIndicator(.visible)
            case .newIncome:
                IncomeEditor(accountColor: account.color) { label, amount, date, frequency in
                    store.addIncome(label: label, amount: amount, startDate: date, frequency: frequency)
                }
                .presentationDetents([.fraction(0.62), .large])
                .presentationDragIndicator(.visible)
            case .editIncome(let income):
                IncomeEditor(accountColor: account.color, income: income) { label, amount, date, frequency in
                    store.updateIncome(income, label: label, amount: amount, startDate: date, frequency: frequency)
                } onDelete: {
                    store.deleteIncome(income)
                }
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.visible)
            case .newAccount:
                AccountEditor(accountColor: account.color) { name in
                    store.addAccount(name: name, startingBalance: 0)
                }
                .presentationDetents([.fraction(0.48), .large])
                .presentationDragIndicator(.visible)
            case .editAccount(let editedAccount):
                AccountEditor(
                    accountColor: editedAccount.color,
                    account: editedAccount,
                    canDelete: store.budget.accounts.count > 1
                ) { name in
                    store.renameAccount(id: editedAccount.id, name: name)
                } onDelete: {
                    store.deleteAccount(id: editedAccount.id)
                }
                .presentationDetents([.fraction(0.52), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Import Backup?", isPresented: importAlertBinding) {
            Button("Cancel", role: .cancel) {
                pendingImportData = nil
            }
            Button("Import", role: .destructive) {
                do {
                    if let pendingImportData {
                        try importBackup(data: pendingImportData)
                        importMessage = "Backup imported."
                    }
                } catch {
                    importMessage = "This backup file could not be restored."
                }
                pendingImportData = nil
            }
        } message: {
            Text("This will replace your current Float data.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatStartSetup)) { _ in
            firstSetupComplete = false
            expandSetupSection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatFocusBalance)) { _ in
            expandedSections.insert(.accounts)
        }
        .onAppear {
            expandSetupSection()
        }
        .onChange(of: store.budget) {
            expandSetupSection()
        }
        .sheet(isPresented: $showDebtPayoff) {
            DebtPayoffView(store: debtPayoffStore)
        }
        .sheet(item: $passcodeFlow) { flow in
            PasscodeManagementView(mode: flow, privacyLock: privacyLock)
                .presentationDetents([.fraction(0.74), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.floatText)
            Spacer()
            if store.isDemoMode {
                Button("Let's Go", action: startOwnBudget)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.floatText)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var setupGuide: some View {
        if let setupStep {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Setup")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.floatText)
                    .tracking(0.8)
                    .textCase(.uppercase)

                Text(setupStep.message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.floatTextMid)
                    .lineSpacing(3)

                setupGuideActions(for: setupStep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func setupGuideActions(for step: SetupStep) -> some View {
        HStack(spacing: 8) {
            switch step {
            case .account:
                setupActionButton("Edit Account") {
                    expandedSections.insert(.accounts)
                    activeSheet = .editAccount(account)
                }
            case .balance:
                setupActionButton("Confirm Balance") {
                    expandedSections.insert(.balance)
                }
            case .income:
                setupActionButton("Add Income") {
                    expandedSections.insert(.income)
                    activeSheet = .newIncome
                }
            case .obligation:
                setupActionButton("Add Bill/Card") {
                    expandedSections.insert(.bills)
                    activeSheet = .newBill
                }
                setupActionButton("Add Debt") {
                    expandedSections.insert(.debts)
                    activeSheet = .newDebt
                }
            case .overview:
                setupActionButton("View Overview") {
                    firstSetupComplete = true
                    goToOverview()
                }
            }

            Button("Skip setup guide") {
                firstSetupComplete = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.floatTextFaint)
            .padding(.horizontal, 8)
            .frame(height: 30)
        }
    }

    private func setupActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.floatText)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.white.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(.black.opacity(0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var toolsSection: some View {
        settingsCard(title: "Tools", section: .tools) {
            VStack(alignment: .leading, spacing: Layout.cardContentGap) {
                guidanceText("Use extra calculators for planning. They stay separate from your main timeline.")
                Button {
                    showDebtPayoff = true
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Debt Payoff")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.floatText)
                            guidanceText("Plan long-term debt payoff separately from your cash flow timeline.")
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.floatTextFaint)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Text("More tools coming soon.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.floatTextFaint)
            }
        }
    }

    private var reserveSection: some View {
        settingsCard(title: "Reserve", section: .reserve) {
            VStack(spacing: Layout.cardContentGap) {
                guidanceText("Set a goal for your emergency reserve and keep track of how much you have saved.")
                settingsControlGroup("Saved so far") {
                    HStack(spacing: 6) {
                        FloatTextField(
                            placeholder: reserveBalancePlaceholder,
                            text: $reserveText,
                            keyboard: .decimalPad
                        )
                        FloatButton(title: "Update") {
                            guard let amount = Double(reserveText) else { return }
                            store.updateReserve(balance: amount)
                            reserveText = ""
                        }
                    }
                }

                settingsControlGroup("Reserve goal") {
                    HStack(spacing: 6) {
                        FloatTextField(
                            placeholder: reserveGoalPlaceholder,
                            text: $reserveGoalText,
                            keyboard: .decimalPad
                        )
                        FloatButton(title: "Set Goal") {
                            guard let amount = Double(reserveGoalText) else { return }
                            store.updateReserveGoal(amount)
                            reserveGoalText = ""
                        }
                    }
                }
            }
        }
    }

    private var balanceSection: some View {
        settingsCard(title: "\(account.name) Balance", section: .balance) {
            VStack(alignment: .leading, spacing: Layout.cardContentGap) {
                guidanceText("Update the cash balance you use for bills whenever your real balance changes.")
                HStack(spacing: 6) {
                    FloatTextField(
                        placeholder: confirmBalancePlaceholder,
                        text: $confirmBalanceText,
                        keyboard: .decimalPad
                    )
                    FloatButton(title: "Confirm") {
                        guard let amount = Double(confirmBalanceText) else { return }
                        store.confirmBalance(amount)
                        confirmBalanceText = ""
                    }
                }
            }
        }
    }

    private var billsSection: some View {
        settingsCard(title: "\(account.name) Bills & Cards", section: .bills) {
            VStack(spacing: 2) {
                guidanceText("Add bills, subscriptions, and credit card payments so Float knows what money is going out.")
                ForEach(account.bills.filter { $0.debtDetails == nil }) { bill in
                    itemRow(
                        title: bill.name,
                        subtitle: "Next: \(labelDate(BudgetMath.nextUnpaidBillDate(bill: bill, paidEarlyBills: account.paidEarlyBills))) · \(bill.frequency.rawValue)",
                        amount: money(bill.amount)
                    ) {
                        activeSheet = .editBill(bill)
                    }
		                }
                addActionRow(title: "Add Bill/Card") {
                    activeSheet = .newBill
                }
		            }
        }
    }

    private var debtsSection: some View {
        settingsCard(title: "\(account.name) Debts", section: .debts) {
            VStack(spacing: 2) {
                guidanceText("Add long-term debts you are paying down, like student loans, car loans, or personal loans.")
                ForEach(account.bills.filter { $0.debtDetails != nil }) { bill in
                    itemRow(
                        title: bill.name,
                        subtitle: "Next: \(labelDate(BudgetMath.nextUnpaidBillDate(bill: bill, paidEarlyBills: account.paidEarlyBills))) · monthly",
                        amount: money(bill.amount)
                    ) {
                        activeSheet = .editDebt(bill)
                    }
                }
                addActionRow(title: "Add Debt") {
                    activeSheet = .newDebt
                }
            }
        }
    }

    private var incomeSection: some View {
        settingsCard(title: "\(account.name) Income", section: .income) {
            VStack(spacing: 2) {
                guidanceText("Add your paycheck or other regular income so Float knows when money comes in.")
                ForEach(account.income.filter { $0.label != "Confirmed balance" }) { income in
                    itemRow(
                        title: income.label,
                        subtitle: "Next: \(labelDate(BudgetMath.nextRecurringDate(startDate: income.startDate, frequency: income.frequency, currentDate: Date.todayString))) · \(income.frequency.rawValue)",
                        amount: money(income.amount)
                    ) {
                        activeSheet = .editIncome(income)
                    }
                }
                addActionRow(title: "Add Income") {
                    activeSheet = .newIncome
                }
            }
        }
    }

    private var accountsSection: some View {
        settingsCard(title: "Accounts", section: .accounts) {
            VStack(spacing: 2) {
                guidanceText("Add the account you use for bills and enter its cash balance. Tap a name to switch the active account.")
                VStack(spacing: 2) {
                    ForEach(Array(store.budget.accounts.enumerated()), id: \.element.id) { index, item in
                        accountRow(item, index: index)
                    }
                }
                .padding(.top, 4)
                addActionRow(title: "Add Account") {
                    activeSheet = .newAccount
                }
            }
        }
    }

	    private func accountMarkerColor(_ index: Int) -> Color {
	        Color(hex: store.selectedPalette.marker(for: index))
	    }

    private func accountRow(_ item: FloatAccount, index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                store.setActiveAccount(item.id)
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(accountMarkerColor(index))
                        .frame(width: 16, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.black.opacity(0.1), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 14, weight: item.id == account.id ? .semibold : .regular))
                            .foregroundStyle(Color.floatText)
                            .lineLimit(1)

                        if item.id == account.id {
                            Text("Active account")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.floatTextFaint)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Edit") {
                activeSheet = .editAccount(item)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.floatText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.white.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.black.opacity(0.06), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    private var generalSettingsSection: some View {
        settingsCard(title: "General Settings", section: .general) {
            VStack(alignment: .leading, spacing: Layout.itemGap) {
                guidanceText("Adjust how Float looks, protect your data, and manage backups.")

                generalGroup("Palette", helper: "Choose the color style that feels easiest to read.") {
                    palettePicker
                }

                generalToggleRow(
                    title: "Show helper text",
                    helper: "Hide or show the small gray notes throughout Settings.",
                    isOn: showGuidance
                ) {
                    showGuidance.toggle()
                }

                generalLockRow()

                generalGroup("Backup", helper: "Export a backup so you do not lose your setup.") {
                    HStack(spacing: 8) {
                        SettingsCompactButton(title: "Export Backup") {
                            prepareExport()
                        }
                        SettingsCompactButton(title: "Import Backup") {
                            showImportPicker = true
                        }
                        Spacer()
                    }
                    if let importMessage {
                        Text(importMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.floatTextFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(backupStatusText)
                        .font(.system(size: 12))
                        .foregroundStyle(backupStatusIsReminder ? Color.floatWarning : Color.floatTextFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                generalNavigationRow(
                    title: "See Onboarding Again",
                    helper: "Review the intro again without changing your current budget."
                ) {
                    NotificationCenter.default.post(name: .floatReplayOnboarding, object: nil)
                }
            }
        }
    }

    private func generalGroup<Content: View>(
        _ title: String,
        helper: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.titleToHelperGap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.floatText)

            if let helper {
                guidanceText(helper)
            }

            content()
                .padding(.top, Layout.helperToControlGap - Layout.titleToHelperGap)
        }
    }

    private func settingsControlGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.helperToControlGap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.floatText)

            content()
        }
    }

    private func generalNavigationRow(
        title: String,
        helper: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Layout.titleToHelperGap) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.floatText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.floatTextFaint)
                }

                if showGuidance {
                    Text(helper)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.floatTextFaint)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func generalToggleRow(
        title: String,
        helper: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Layout.titleToHelperGap) {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.floatText)

                    Spacer()

                    SettingsSwitch(
                        isOn: isOn,
                        highContrast: colorSchemeContrast == .increased,
                        differentiateWithoutColor: differentiateWithoutColor
                    )
                }

                if showGuidance {
                    Text(helper)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.floatTextFaint)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    private func generalLockRow() -> some View {
        VStack(alignment: .leading, spacing: Layout.helperToControlGap) {
            generalToggleRow(
                title: "App Lock",
                helper: "Use Face ID or a passcode to keep your numbers private.",
                isOn: privacyLock.isEnabled,
                action: handleAppLockTap
            )

            if privacyLock.hasPasscode {
                SettingsCompactButton(title: "Change Passcode") {
                    passcodeFlow = .change
                }
            }
        }
    }

    private func handleAppLockTap() {
        if privacyLock.isEnabled {
            passcodeFlow = .disable
        } else if privacyLock.hasPasscode {
            privacyLock.setEnabled(true)
        } else {
            passcodeFlow = .setup
        }
    }

    private var palettePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 1) {
                ForEach(AccountPalette.all) { palette in
                    Button {
                        store.selectPalette(palette)
                    } label: {
                        HStack(spacing: 10) {
                            swatches(for: palette)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(palette.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.floatText)
                                if showGuidance {
                                    Text(palette.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.floatTextFaint)
                                }
                            }

                            Spacer()

                            if store.selectedPalette.id == palette.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.floatTextMid)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func swatches(for palette: AccountPalette) -> some View {
        HStack(spacing: -3) {
            ForEach(Array(palette.markers.prefix(4).enumerated()), id: \.offset) { _, hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .stroke(.black.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
        .frame(width: 48, alignment: .leading)
    }

    @ViewBuilder
    private func guidanceText(_ text: String) -> some View {
        if showGuidance {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingImportData != nil },
            set: { isPresented in
                if !isPresented {
                    pendingImportData = nil
                }
            }
        )
    }

    private func readImportData(from url: URL) throws -> Data {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    private func relativeBackupDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfDate = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

        switch days {
        case 0:
            return "today"
        case 1:
            return "yesterday"
        case 2...13:
            return "\(days) days ago"
        default:
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }

    private func settingsCard<Content: View, Accessory: View>(
        title: String,
        section: SettingsSection,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    toggle(section)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 12)
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.floatText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.floatTextMid)

                accessory()
            }
            .frame(height: 34)

            if expandedSections.contains(section) {
                VStack(alignment: .leading, spacing: Layout.cardContentGap) {
                    content()
                }
                .padding(.top, 6)
                .transition(.identity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, expandedSections.contains(section) ? 12 : 8)
        .background(.white.opacity(0.32))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.black.opacity(0.045), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        section: SettingsSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsCard(title: title, section: section, content: content) {
            EmptyView()
        }
    }

    private func iconAddButton(title: String, action: @escaping () -> Void) -> some View {
        SettingsCompactButton(title: title, systemImage: "plus", action: action)
    }

    private func addActionRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Color.floatText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Layout.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private struct SettingsCompactButton: View {
        var title: String
        var systemImage: String?
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 5) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 13))
                }
                .foregroundStyle(Color.floatText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.white.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.black.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private struct SettingsSwitch: View {
        var isOn: Bool
        var highContrast: Bool
        var differentiateWithoutColor: Bool

        var body: some View {
            HStack(spacing: 6) {
                if differentiateWithoutColor {
                    Text(isOn ? "On" : "Off")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.floatTextMid)
                }

                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.floatAccent : Color.floatTextFaint.opacity(highContrast ? 0.45 : 0.28))
                        .overlay(
                            Capsule()
                                .stroke(highContrast ? Color.floatText : .black.opacity(0.08), lineWidth: highContrast ? 1 : 0.5)
                        )

                    Circle()
                        .fill(.white)
                        .overlay {
                            if differentiateWithoutColor {
                                Image(systemName: isOn ? "checkmark" : "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(isOn ? Color.floatAccent : Color.floatTextFaint)
                            }
                        }
                        .frame(width: 18, height: 18)
                        .padding(2)
                }
                .frame(width: 38, height: 21)
            }
        }
    }

    private struct SettingsToggleRow: View {
        var title: String
        @Binding var isOn: Bool
        var highContrast: Bool
        var differentiateWithoutColor: Bool

        var body: some View {
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.floatText)

                    Spacer()

                    SettingsSwitch(
                        isOn: isOn,
                        highContrast: highContrast,
                        differentiateWithoutColor: differentiateWithoutColor
                    )
                }
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
        }
    }

    private struct SettingsToggleButton: View {
        var title: String
        var isOn: Bool
        var highContrast: Bool
        var differentiateWithoutColor: Bool
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                SettingsToggleContent(
                    title: title,
                    isOn: isOn,
                    highContrast: highContrast,
                    differentiateWithoutColor: differentiateWithoutColor
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isButton)
        }
    }

    private struct SettingsToggleContent: View {
        var title: String
        var isOn: Bool
        var highContrast: Bool
        var differentiateWithoutColor: Bool

        var body: some View {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.floatText)

                Spacer()

                SettingsSwitch(
                    isOn: isOn,
                    highContrast: highContrast,
                    differentiateWithoutColor: differentiateWithoutColor
                )
            }
            .frame(height: 24)
            .contentShape(Rectangle())
        }
    }

    private func itemRow(title: String, subtitle: String, amount: String, edit: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.floatText)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.floatTextFaint)
            }
            Spacer()
            Text(amount)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.floatText)
            Button("Edit", action: edit)
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.floatText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.white.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.black.opacity(0.06), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    private func toggle(_ section: SettingsSection) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func expandSetupSection() {
        guard let setupStep else { return }

        switch setupStep {
        case .account:
            expandedSections.insert(.accounts)
        case .balance:
            expandedSections.insert(.balance)
        case .income:
            expandedSections.insert(.income)
        case .obligation:
            expandedSections.insert(.bills)
            expandedSections.insert(.debts)
        case .overview:
            break
        }
    }

    private var exportFilename: String {
        let stamp = ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        return "float-backup-\(stamp)"
    }

    private func prepareExport() {
        do {
            exportDocument = try BackupDocument(budget: store.budget, debtPayoff: debtPayoffStore.ledger)
            showExportPicker = true
        } catch {
            importMessage = "Export failed."
        }
    }

    private func importBackup(data: Data) throws {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(FloatBackupPayload.self, from: data) {
            let budgetData = try JSONEncoder().encode(payload.budget)
            try store.importBackup(data: budgetData)
            debtPayoffStore.replaceLedger(payload.debtPayoff ?? DebtPayoffLedger())
            return
        }

        try store.importBackup(data: data)
    }
}

enum SettingsSection: CaseIterable, Hashable {
    case accounts
    case balance
    case income
    case bills
    case debts
    case reserve
    case general
    case tools
}

enum PasscodeFlow: Identifiable {
    case setup
    case change
    case disable

    var id: String {
        switch self {
        case .setup: "setup"
        case .change: "change"
        case .disable: "disable"
        }
    }
}

private enum PasscodeEntryField {
    case current
    case new
    case confirm
}

private enum SetupStep {
    case account
    case balance
    case income
    case obligation
    case overview

    var message: String {
        switch self {
        case .account:
            return "Start with the account you actually use to pay bills. Edit the account, then enter its cash balance so Float has a real starting point."
        case .balance:
            return "Confirm the cash balance you use for bills. This gives Float the starting number for your timeline."
        case .income:
            return "Next, add your paycheck or other regular income. This gives Float the rhythm of when money comes in."
        case .obligation:
            return "Now add your first bill, card payment, or debt. This is where Float starts showing the pressure between paychecks."
        case .overview:
            return "Your first timeline is ready. Go back to Overview to see whether this account is floating or sinking."
        }
    }
}

enum SettingsSheet: Identifiable {
    case newBill
    case editBill(BudgetBill)
    case newDebt
    case editDebt(BudgetBill)
    case newIncome
    case editIncome(BudgetIncome)
    case newAccount
    case editAccount(FloatAccount)

    var id: String {
        switch self {
        case .newBill: "new-bill"
        case .editBill(let bill): "edit-bill-\(bill.id)"
        case .newDebt: "new-debt"
        case .editDebt(let bill): "edit-debt-\(bill.id)"
        case .newIncome: "new-income"
        case .editIncome(let income): "edit-income-\(income.id)"
        case .newAccount: "new-account"
        case .editAccount(let account): "edit-account-\(account.id)"
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data("{}".utf8)) {
        self.data = data
    }

    init(budget: FloatBudget, debtPayoff: DebtPayoffLedger) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(FloatBackupPayload(budget: budget, debtPayoff: debtPayoff))
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct PasscodeManagementView: View {
    @Environment(\.dismiss) private var dismiss

    var mode: PasscodeFlow
    @ObservedObject var privacyLock: PrivacyLockStore

    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var errorText: String?
    @State private var activeField: PasscodeEntryField = .new

    var body: some View {
        EditorShell(accountColor: "EEE9E7", title: title) {
            VStack(alignment: .leading, spacing: 10) {
                if needsCurrentPasscode {
                    PasscodeInputRow(
                        title: "Current passcode",
                        count: currentPasscode.count,
                        isActive: activeField == .current,
                        hasError: errorText != nil
                    ) {
                        activeField = .current
                    }
                }

                if mode != .disable {
                    PasscodeInputRow(
                        title: "New passcode",
                        count: newPasscode.count,
                        isActive: activeField == .new,
                        hasError: errorText != nil
                    ) {
                        activeField = .new
                    }

                    PasscodeInputRow(
                        title: "Enter new passcode again",
                        count: confirmPasscode.count,
                        isActive: activeField == .confirm,
                        hasError: errorText != nil
                    ) {
                        activeField = .confirm
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.floatWarning)
                }

                PasscodeKeypad(
                    onDigit: appendDigit,
                    onDelete: deleteDigit,
                    onConfirm: confirm
                )
                .padding(.vertical, 2)

                HStack(spacing: 10) {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }

                    SheetActionButton(title: confirmTitle, fill: .primary) {
                        confirm()
                    }
                }
            }
        }
        .onAppear {
            activeField = needsCurrentPasscode ? .current : .new
        }
    }

    private var title: String {
        switch mode {
        case .setup: "Set Passcode"
        case .change: "Change Passcode"
        case .disable: "Turn Off App Lock"
        }
    }

    private var confirmTitle: String {
        switch mode {
        case .setup: "Set"
        case .change: "Save"
        case .disable: "Turn Off"
        }
    }

    private var needsCurrentPasscode: Bool {
        mode == .change || mode == .disable
    }

    private func confirm() {
        if needsCurrentPasscode, !privacyLock.validatePasscode(currentPasscode) {
            errorText = "Current passcode is incorrect."
            activeField = .current
            return
        }

        if mode == .disable {
            privacyLock.setEnabled(false)
            dismiss()
            return
        }

        guard (4...6).contains(newPasscode.count) else {
            errorText = "Use 4 to 6 digits."
            activeField = .new
            return
        }

        guard newPasscode == confirmPasscode else {
            errorText = "New passcodes do not match."
            activeField = .confirm
            return
        }

        privacyLock.setPasscode(newPasscode)
        privacyLock.setEnabled(true)
        dismiss()
    }

    private func appendDigit(_ digit: String) {
        errorText = nil
        switch activeField {
        case .current:
            guard currentPasscode.count < 6 else { return }
            currentPasscode.append(digit)
        case .new:
            guard newPasscode.count < 6 else { return }
            newPasscode.append(digit)
        case .confirm:
            guard confirmPasscode.count < 6 else { return }
            confirmPasscode.append(digit)
        }
    }

    private func deleteDigit() {
        switch activeField {
        case .current:
            guard !currentPasscode.isEmpty else { return }
            currentPasscode.removeLast()
        case .new:
            guard !newPasscode.isEmpty else { return }
            newPasscode.removeLast()
        case .confirm:
            guard !confirmPasscode.isEmpty else { return }
            confirmPasscode.removeLast()
        }
    }
}

struct BillEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var bill: BudgetBill?
    var onSave: (String, Double, Date, Frequency) -> Void
    var onDelete: (() -> Void)?
    var onPaidEarly: (() -> Void)?

    @State private var name: String
    @State private var amount: String
    @State private var date: Date
    @State private var dateWasChosen: Bool
    @State private var saveAttempted = false
    @State private var frequency: Frequency
    @State private var showDeleteAlert = false

    init(
        accountColor: String,
        bill: BudgetBill? = nil,
        onSave: @escaping (String, Double, Date, Frequency) -> Void,
        onDelete: (() -> Void)? = nil,
        onPaidEarly: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete
        self.onPaidEarly = onPaidEarly
        _name = State(initialValue: bill?.name ?? "")
        _amount = State(initialValue: bill.map { String($0.amount) } ?? "")
        _date = State(initialValue: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
        _dateWasChosen = State(initialValue: bill != nil)
        _frequency = State(initialValue: bill?.frequency ?? .monthly)
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: bill == nil ? "New Bill" : "Edit Bill") {
            labeled("Bill name") {
                FloatTextField(placeholder: "", text: $name)
            }
            labeled("Amount") {
                FloatTextField(placeholder: "", text: $amount, keyboard: .decimalPad)
            }
            labeled("Frequency") {
                FrequencyPicker(frequency: $frequency)
            }
            labeled("Date") {
                SheetDatePicker(
                    date: $date,
                    wasChosen: $dateWasChosen,
                    showMissingState: saveAttempted && !dateWasChosen
                )
            }

            if let onPaidEarly {
                SheetActionButton(title: "Paid Early", fill: .secondary) {
                    onPaidEarly()
                    dismiss()
                }
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    saveAttempted = true
                    let nextName = name.isEmpty ? bill?.name ?? "" : name
                    let parsedAmount = Double(amount) ?? bill?.amount ?? 0
                    guard dateWasChosen, !nextName.isEmpty else { return }
                    onSave(nextName, parsedAmount, date, frequency)
                    dismiss()
                }
            }
        }
        .alert("Delete \(bill?.name ?? "Bill")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}

struct IncomeEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var income: BudgetIncome?
    var onSave: (String, Double, Date, Frequency) -> Void
    var onDelete: (() -> Void)?

    @State private var label: String
    @State private var amount: String
    @State private var date: Date
    @State private var dateWasChosen: Bool
    @State private var saveAttempted = false
    @State private var frequency: Frequency
    @State private var showDeleteAlert = false

    init(
        accountColor: String,
        income: BudgetIncome? = nil,
        onSave: @escaping (String, Double, Date, Frequency) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.income = income
        self.onSave = onSave
        self.onDelete = onDelete
        _label = State(initialValue: income?.label ?? "Paycheck")
        _amount = State(initialValue: income.map { String($0.amount) } ?? "")
        _date = State(initialValue: income.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
        _dateWasChosen = State(initialValue: income != nil)
        _frequency = State(initialValue: income?.frequency ?? .biweekly)
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: income == nil ? "New Income" : "Edit Income") {
            labeled("Name") {
                FloatTextField(placeholder: "Paycheck", text: $label)
            }
            labeled("Amount") {
                FloatTextField(placeholder: "", text: $amount, keyboard: .decimalPad)
            }
            labeled("Frequency") {
                FrequencyPicker(frequency: $frequency)
            }
            labeled("Date") {
                SheetDatePicker(
                    date: $date,
                    wasChosen: $dateWasChosen,
                    showMissingState: saveAttempted && !dateWasChosen
                )
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    saveAttempted = true
                    let nextLabel = label.isEmpty ? income?.label ?? "" : label
                    let parsedAmount = Double(amount) ?? income?.amount ?? 0
                    guard dateWasChosen, !nextLabel.isEmpty else { return }
                    onSave(nextLabel, parsedAmount, date, frequency)
                    dismiss()
                }
            }
        }
        .alert("Delete \(income?.label ?? "Income")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}

struct DebtBillEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var bill: BudgetBill?
    var onSave: (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var startingBalance: String
    @State private var currentPrincipal: String
    @State private var accruedInterest: String
    @State private var balanceDate: Date
    @State private var apr: String
    @State private var minimumPayment: String
    @State private var monthlyPayment: String
    @State private var paymentDate: Date
    @State private var showDeleteAlert = false
    @State private var showIncompleteSnapshotAlert = false
    @State private var showLargeBalanceAlert = false

    init(
        accountColor: String,
        bill: BudgetBill? = nil,
        onSave: @escaping (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete

        let details = bill?.debtDetails
        _name = State(initialValue: bill?.name ?? "")
        _startingBalance = State(initialValue: details.map { String($0.startingBalance) } ?? "")
        _currentPrincipal = State(initialValue: details.map { String($0.currentPrincipal) } ?? "")
        _accruedInterest = State(initialValue: details.map { String($0.accruedInterest) } ?? "")
        _balanceDate = State(initialValue: details.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) } ?? Date())
        _apr = State(initialValue: details.map { String($0.interestRateAPR) } ?? "")
        _minimumPayment = State(initialValue: details.map { String($0.minimumPayment) } ?? "")
        _monthlyPayment = State(initialValue: bill.map { String($0.amount) } ?? "")
        _paymentDate = State(initialValue: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: bill == nil ? "New Debt" : "Debt Details") {
            payoffSummary

            labeled("Debt Name") {
                FloatTextField(placeholder: "Student Loan", text: $name)
            }
            labeled("Starting Balance") {
                FloatTextField(placeholder: "93462.17", text: $startingBalance, keyboard: .decimalPad)
            }
            labeled("Payment Date") {
                editorDatePicker(date: $paymentDate)
            }
            labeled("Interest Rate") {
                FloatTextField(placeholder: "4.485", text: $apr, keyboard: .decimalPad)
            }
            labeled("Minimum Payment") {
                FloatTextField(placeholder: "0.00", text: $minimumPayment, keyboard: .decimalPad)
            }
            labeled("Current Principal") {
                FloatTextField(placeholder: "70803.93", text: $currentPrincipal, keyboard: .decimalPad)
            }
            labeled("Accrued Interest") {
                FloatTextField(placeholder: "243.60", text: $accruedInterest, keyboard: .decimalPad)
            }
            labeled("Balance Date") {
                editorDatePicker(date: $balanceDate)
            }
            labeled("Monthly Payment") {
                FloatTextField(placeholder: "0.00", text: $monthlyPayment, keyboard: .decimalPad)
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        cancel()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    attemptSave()
                }
            }
        }
        .interactiveDismissDisabled(snapshotHasChanges)
        .alert("Delete \(bill?.name ?? "Debt")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
        .alert("Update Balance Snapshot", isPresented: $showIncompleteSnapshotAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Current Principal, Accrued Interest, and Balance Date need to be updated together.")
        }
        .alert("Balance Looks Far Off", isPresented: $showLargeBalanceAlert) {
            Button("Review", role: .cancel) {}
            Button("Save Anyway") {
                saveAndDismiss()
            }
        } message: {
            Text("The new principal plus accrued interest is far from the previous balance snapshot.")
        }
    }

    private var payoffSummary: some View {
        let balance = (Double(currentPrincipal) ?? bill?.debtDetails?.currentPrincipal ?? 0) +
            (Double(accruedInterest) ?? bill?.debtDetails?.accruedInterest ?? 0)
        let payment = Double(monthlyPayment) ?? bill?.amount ?? 0
        let rate = Double(apr) ?? bill?.debtDetails?.interestRateAPR ?? 0
        let months = estimatedMonths(balance: balance, payment: payment, apr: rate)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.floatTextFaint)
                .tracking(0.8)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                detailMetric("Current Debt", money(balance))
                Spacer()
                detailMetric("Payoff", payoffText(months))
            }
        }
        .padding(12)
        .background(.white.opacity(0.52))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.floatText)
        }
    }

    private func payoffText(_ months: Int?) -> String {
        guard let months else { return "Not enough" }
        if months == 0 { return "Paid off" }
        let date = Calendar.current.date(byAdding: .month, value: months, to: paymentDate) ?? paymentDate
        return labelDate(date.ymdString)
    }

    private func estimatedMonths(balance: Double, payment: Double, apr: Double) -> Int? {
        var balance = balance
        guard balance > 0 else { return 0 }
        let monthlyRate = max(0, apr) / 100 / 12
        guard payment > balance * monthlyRate else { return nil }

        for month in 1...600 {
            balance += balance * monthlyRate
            balance -= payment
            if balance <= 0 {
                return month
            }
        }

        return nil
    }

    private var snapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.issue(
            originalPrincipal: bill?.debtDetails?.currentPrincipal,
            originalAccruedInterest: bill?.debtDetails?.accruedInterest,
            originalBalanceDate: bill?.debtDetails.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            originalAPR: bill?.debtDetails?.interestRateAPR,
            originalMonthlyPayment: bill?.amount,
            originalPaymentDate: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var incompleteSnapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.incompleteSnapshotIssue(
            originalPrincipal: bill?.debtDetails?.currentPrincipal,
            originalAccruedInterest: bill?.debtDetails?.accruedInterest,
            originalBalanceDate: bill?.debtDetails.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var snapshotHasChanges: Bool {
        guard let details = bill?.debtDetails,
              let originalDate = Date.yyyyMMdd.date(from: details.balanceDate) else {
            return false
        }

        let principal = Double(currentPrincipal) ?? details.currentPrincipal
        let interest = Double(accruedInterest) ?? details.accruedInterest
        return abs(principal - details.currentPrincipal) >= 0.005 ||
            abs(interest - details.accruedInterest) >= 0.005 ||
            balanceDate.ymdString != originalDate.ymdString
    }

    private func attemptSave() {
        switch snapshotIssue {
        case .incompleteSnapshot:
            showIncompleteSnapshotAlert = true
        case .largeBalanceChange:
            showLargeBalanceAlert = true
        case nil:
            saveAndDismiss()
        }
    }

    private func cancel() {
        attemptExit()
    }

    private func attemptExit() {
        switch snapshotIssue {
        case .incompleteSnapshot:
            showIncompleteSnapshotAlert = true
        case .largeBalanceChange:
            showLargeBalanceAlert = true
        case nil:
            dismiss()
        }
    }

    private func saveAndDismiss() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onSave(
            trimmedName,
            Double(startingBalance) ?? bill?.debtDetails?.startingBalance ?? 0,
            Double(currentPrincipal) ?? bill?.debtDetails?.currentPrincipal ?? 0,
            Double(accruedInterest) ?? bill?.debtDetails?.accruedInterest ?? 0,
            balanceDate,
            Double(apr) ?? bill?.debtDetails?.interestRateAPR ?? 0,
            Double(minimumPayment) ?? bill?.debtDetails?.minimumPayment ?? 0,
            Double(monthlyPayment) ?? bill?.amount ?? 0,
            paymentDate
        )
        dismiss()
    }

    private func editorDatePicker(date: Binding<Date>) -> some View {
        DatePicker("", selection: date, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(.system(size: 14))
            .tint(Color.floatText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.floatBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var account: FloatAccount?
    var canDelete: Bool
    var onSave: (String) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var showDeleteAlert = false

    init(
        accountColor: String,
        account: FloatAccount? = nil,
        canDelete: Bool = false,
        onSave: @escaping (String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.account = account
        self.canDelete = canDelete
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: account?.name ?? "")
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: account == nil ? "New Account" : "Edit Account") {
            labeled("Account name") {
                FloatTextField(placeholder: "", text: $name)
            }

            HStack(spacing: 10) {
                if canDelete {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Save", fill: .primary) {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    onSave(trimmedName)
                    dismiss()
                }
            }
        }
        .alert("Delete \(account?.name ?? "Account")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("All balances and transactions under this account will be lost.")
        }
    }
}

struct EditorShell<Content: View>: View {
    var accountColor: String
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: accountColor).opacity(0.75), Color(hex: accountColor).opacity(0.42), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.floatText)
                        .padding(.bottom, 10)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.always, axes: .vertical)
        }
    }
}

struct SheetActionButton: View {
    enum Fill {
        case primary
        case secondary
    }

    var title: String
    var fill: Fill
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.floatText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(fill == .primary ? .white.opacity(0.78) : .white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SheetDatePicker: View {
    @Binding var date: Date
    @Binding var wasChosen: Bool
    var showMissingState: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 14))
                .tint(Color.floatText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .opacity(wasChosen ? 1 : 0.02)
                .onChange(of: date) {
                    wasChosen = true
                }
                .simultaneousGesture(TapGesture().onEnded {
                    wasChosen = true
                })

            if !wasChosen {
                Text("Select date")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.floatTextFaint)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showMissingState ? Color.floatWarning : Color.floatBorder, lineWidth: showMissingState ? 1 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FrequencyPicker: View {
    @Binding var frequency: Frequency

    var body: some View {
        Picker("Frequency", selection: $frequency) {
            ForEach(Frequency.allCases) { item in
                Text(item.label).tag(item)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 14))
        .foregroundStyle(Color.floatText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.floatBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@ViewBuilder
private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(Color.floatText)
        content()
    }
}
