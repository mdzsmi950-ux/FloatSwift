import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    var mode: SettingsMode = .income
    var goToOverview: () -> Void
    var startOwnBudget: () -> Void
    @ObservedObject var privacyLock: PrivacyLockStore

    @State private var expandedSections = Set(SettingsSection.allCases)
    @State private var confirmBalanceText = ""
    @State private var reserveText = ""
    @State private var reserveGoalText = ""
    @State private var confirmBalanceError: String?
    @State private var reserveError: String?
    @State private var reserveGoalError: String?
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var exportDocument = BackupDocument()
    @State private var pendingImportData: Data?
    @State private var importMessage: String?
    @State private var activeSheet: SettingsSheet?
    @State private var passcodeFlow: PasscodeFlow?
    @AppStorage(AppStorageKey.settingsGuidanceVisible) private var showGuidance = true
    @AppStorage(AppStorageKey.firstSetupComplete) private var firstSetupComplete = false
    @AppStorage(AppStorageKey.firstAccountSetupComplete) private var firstAccountSetupComplete = false

    private enum Layout {
        static let sectionGap: CGFloat = 12
        static let cardContentGap: CGFloat = 10
        static let itemGap: CGFloat = 12
        static let itemGapWithoutHelper: CGFloat = 18
        static let titleToHelperGap: CGFloat = 4
        static let helperToControlGap: CGFloat = 8
        static let rowVerticalPadding: CGFloat = 6
        static let generalPaddingWithoutHelper: CGFloat = 2
    }

    private var account: FloatAccount {
        store.activeAccount
    }

    private var sortedIncomeItems: [BudgetIncome] {
        account.income
            .filter { $0.label != "Confirmed balance" }
            .sorted {
                BudgetMath.nextRecurringDate(startDate: $0.startDate, frequency: $0.frequency, currentDate: Date.todayString) <
                    BudgetMath.nextRecurringDate(startDate: $1.startDate, frequency: $1.frequency, currentDate: Date.todayString)
            }
    }

    private var sortedOutItems: [BudgetBill] {
        account.bills.sorted {
            BudgetMath.nextUnpaidBillDate(bill: $0, paidEarlyBills: account.paidEarlyBills) <
                BudgetMath.nextUnpaidBillDate(bill: $1, paidEarlyBills: account.paidEarlyBills)
        }
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

        if !firstAccountSetupComplete {
            return .account
        }

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
                    switch mode {
                    case .income:
                        incomeSection
                    case .out:
                        billsSection
                        debtPayoffSection
                    case .settings:
                        setupGuide
                        accountsSection
                        balanceSection
                        reserveSection
                        generalSettingsSection
                    }
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
                BillEditor(accountColor: account.color) { name, amount, date, frequency, debtDetails in
                    store.addBill(name: name, amount: amount, startDate: date, frequency: frequency, debtDetails: debtDetails)
                }
                .presentationDetents([.fraction(0.76), .large])
                .presentationDragIndicator(.visible)
            case .editBill(let bill):
                BillEditor(accountColor: account.color, bill: bill) { name, amount, date, frequency, debtDetails in
                    store.updateBill(bill, name: name, amount: amount, startDate: date, frequency: frequency, debtDetails: debtDetails)
                } onDelete: {
                    store.deleteBill(bill)
                } onPaidEarly: {
                    store.payBillEarly(bill)
                }
                .presentationDetents([.fraction(0.86), .large])
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
                let widgetAccount = store.budget.widgetAccount
                AccountEditor(
                    accountColor: editedAccount.color,
                    account: editedAccount,
                    canDelete: store.budget.accounts.count > 1,
                    isShownInWidget: store.budget.widgetAccountId == editedAccount.id,
                    currentWidgetAccountName: widgetAccount?.id == editedAccount.id ? nil : widgetAccount?.name
                ) { name in
                    store.renameAccount(id: editedAccount.id, name: name)
                } onWidgetVisibilityChange: { isShown in
                    store.setWidgetAccount(id: isShown ? editedAccount.id : nil)
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
                        try store.importBackup(data: pendingImportData)
                        importMessage = "Backup imported."
                    }
                } catch {
                    importMessage = "This backup file could not be restored."
                }
                pendingImportData = nil
            }
        } message: {
            Text("Importing this backup will replace your current accounts, balances, income, bills, cards, debts, and reserve. Export a backup first if you want to keep a copy of your current setup.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatStartSetup)) { _ in
            firstAccountSetupComplete = false
            firstSetupComplete = false
            expandSetupSection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatFocusBalance)) { _ in
            expandedSections.insert(.balance)
        }
        .onAppear {
            expandSetupSection()
        }
        .onChange(of: store.budget) {
            expandSetupSection()
        }
        .fullScreenCover(item: $passcodeFlow) { flow in
            PasscodeManagementView(mode: flow, privacyLock: privacyLock)
        }
    }

    private var header: some View {
        HStack {
            Text(mode.title)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set Up Your Budget")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.floatText)
                            .tracking(0.8)
                            .textCase(.uppercase)

                        Text("Step \(setupStep.number) of \(SetupStep.totalSteps)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.floatTextFaint)
                    }

                    Spacer()

                    setupProgress(for: setupStep)
                }

                Text(setupStep.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.floatText)

                Text(setupStep.message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.floatTextMid)
                    .lineSpacing(3)

                setupGuideActions(for: setupStep)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white.opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.black.opacity(0.045), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func setupProgress(for step: SetupStep) -> some View {
        HStack(spacing: 5) {
            ForEach(1...SetupStep.totalSteps, id: \.self) { number in
                Capsule()
                    .fill(number <= step.number ? Color.floatText : Color.floatTextFaint.opacity(0.22))
                    .frame(width: number == step.number ? 18 : 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private func setupGuideActions(for step: SetupStep) -> some View {
        HStack(spacing: 8) {
            switch step {
            case .account:
                setupActionButton("Edit Account") {
                    firstAccountSetupComplete = true
                    expandedSections.insert(.accounts)
                    activeSheet = .editAccount(account)
                }
                setupActionButton("Keep Name") {
                    firstAccountSetupComplete = true
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
                setupActionButton("Add Outgoing") {
                    expandedSections.insert(.bills)
                    activeSheet = .newBill
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
        Button {
            UIApplication.dismissKeyboard()
            action()
        } label: {
            Text(title)
        }
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

    @ViewBuilder
    private var debtPayoffSection: some View {
        if debtOverviewItems.isEmpty == false {
            let summary = DebtPayoffMath.summary(for: debtOverviewItems)

            settingsCard(title: "Debt Overview", section: .debtPayoff) {
                VStack(alignment: .leading, spacing: Layout.cardContentGap) {
                    guidanceText("Calculated from the debt payments listed in Out.")

                    HStack(alignment: .top, spacing: 12) {
                        debtOverviewMetric(
                            title: "Total Debt",
                            value: money(summary.totalDebt),
                            color: .floatText
                        )

                        debtOverviewMetric(
                            title: "Monthly Payments",
                            value: money(summary.monthlyPayments),
                            color: .floatTextMid
                        )
                    }

                    debtOverviewMetric(
                        title: "Estimated Debt-Free Date",
                        value: debtOverviewDateText(summary),
                        color: summary.canEstimate ? .floatAccent : .floatWarning
                    )
                }
            }
        }
    }

    private var debtOverviewItems: [DebtPayoffItem] {
        account.bills.compactMap { bill in
            guard let details = bill.debtDetails else { return nil }
            return DebtPayoffItem(
                id: "out-\(bill.id)",
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
        }
    }

    private func debtOverviewDateText(_ summary: DebtPayoffSummary) -> String {
        if !summary.canEstimate {
            return "Not enough to estimate"
        }

        guard let date = summary.estimatedDebtFreeDate else {
            return "-"
        }

        return labelDate(date)
    }

    private func debtOverviewMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            guard let amount = parseAmount(reserveText) else {
                                reserveError = "Enter a valid saved amount."
                                return
                            }
                            store.updateReserve(balance: amount)
                            reserveText = ""
                            reserveError = nil
                        }
                    }
                    settingsFieldError(reserveError)
                }

                settingsControlGroup("Reserve goal") {
                    HStack(spacing: 6) {
                        FloatTextField(
                            placeholder: reserveGoalPlaceholder,
                            text: $reserveGoalText,
                            keyboard: .decimalPad
                        )
                        FloatButton(title: "Set Goal") {
                            guard let amount = parseAmount(reserveGoalText) else {
                                reserveGoalError = "Enter a valid reserve goal."
                                return
                            }
                            store.updateReserveGoal(amount)
                            reserveGoalText = ""
                            reserveGoalError = nil
                        }
                    }
                    settingsFieldError(reserveGoalError)
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
                        guard let amount = parseAmount(confirmBalanceText) else {
                            confirmBalanceError = "Enter a valid balance."
                            return
                        }
                        store.confirmBalance(amount)
                        confirmBalanceText = ""
                        confirmBalanceError = nil
                    }
                }
                settingsFieldError(confirmBalanceError)
            }
        }
    }

    private var billsSection: some View {
        settingsCard(title: "\(account.name) Outgoing Payments", section: .bills) {
            VStack(spacing: 2) {
                guidanceText("Add all money going out: bills, cards, debts, subscriptions, transfers out, and other outgoing payments.")
                ForEach(sortedOutItems) { bill in
                    itemRow(
                        title: bill.name,
                        subtitle: "Next: \(labelDate(BudgetMath.nextUnpaidBillDate(bill: bill, paidEarlyBills: account.paidEarlyBills))) · \(bill.frequency.rawValue)",
                        amount: money(bill.amount)
                    ) {
                        activeSheet = .editBill(bill)
                    }
                }
                addActionRow(title: "Add Outgoing Payment") {
                    activeSheet = .newBill
                }
            }
        }
    }

    private var incomeSection: some View {
        settingsCard(title: "\(account.name) Income", section: .income) {
            VStack(spacing: 2) {
                guidanceText("Add all money coming in so Float knows when money arrives.")
                ForEach(sortedIncomeItems) { income in
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
                guidanceText("Add the account you use for bills and enter its cash balance. Tap a name to view and edit that account.")
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
                            Text("Selected")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.floatTextFaint)
                        }

                        if item.id == store.budget.widgetAccountId {
                            Text("Widget")
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
                generalGroup("Palette", helper: "Choose the color style that feels easiest to read.") {
                    palettePicker
                }

                generalDivider

                generalToggleRow(
                    title: "Show helper text",
                    helper: "Hide or show the small gray notes throughout Settings.",
                    isOn: showGuidance
                ) {
                    showGuidance.toggle()
                }

                generalDivider

                generalLockRow()

                generalDivider

                generalGroup("Backup", helper: "Export a backup to save your current setup.\nImporting a backup will replace your current accounts, balances, income, bills, debts, and reserve.") {
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

                generalDivider

                generalNavigationRow(
                    title: "Onboarding",
                    helper: "Review the intro again without changing your current budget."
                ) {
                    NotificationCenter.default.post(name: .floatReplayOnboarding, object: nil)
                }
            }
        }
    }

    private var generalDivider: some View {
        Rectangle()
            .fill(.black.opacity(0.07))
            .frame(height: 0.5)
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
        .padding(.vertical, showGuidance ? 0 : Layout.generalPaddingWithoutHelper)
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
        .padding(.vertical, showGuidance ? 0 : Layout.generalPaddingWithoutHelper)
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
        .padding(.vertical, showGuidance ? 0 : Layout.generalPaddingWithoutHelper)
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
        .floatCardSurface(cornerRadius: 18, fillOpacity: 0.82)
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
            exportDocument = try BackupDocument(budget: store.budget)
            showExportPicker = true
        } catch {
            importMessage = "Export failed."
        }
    }

}
