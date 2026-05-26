import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BudgetStore
    var goToOverview: () -> Void
    var startOwnBudget: () -> Void

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
    @State private var editingAccountId: String?
    @State private var editingAccountName = ""
    @State private var accountToDelete: FloatAccount?

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

    private var confirmBalancePlaceholder: String {
        account.currentBalance == 0 ? "Confirm balance for \(account.name)" : money(account.currentBalance)
    }

    private var reserveBalancePlaceholder: String {
        account.reserveBalance == 0 ? "Reserve balance" : money(account.reserveBalance)
    }

    private var reserveGoalPlaceholder: String {
        account.reserveGoal == 0 ? "Reserve goal" : money(account.reserveGoal)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: 10) {
                    accountsSection
                    balanceSection
                    billsSection
                    incomeSection
                    reserveSection
                    paletteSection
                    backupSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 42)
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
                AccountEditor(accountColor: account.color) { name, startingBalance in
                    store.addAccount(name: name, startingBalance: startingBalance)
                }
                .presentationDetents([.fraction(0.5), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Delete Account?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let accountToDelete {
                    store.deleteAccount(id: accountToDelete.id)
                }
                accountToDelete = nil
            }
        } message: {
            Text("All balances and transactions under this account will be lost.")
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
            Text("This will replace your current Float data.")
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
            Button("Done", action: goToOverview)
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.floatText)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(.white.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.black.opacity(0.08), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.bottom, 24)
    }

    private var backupSection: some View {
        settingsCard(title: "Backup", section: .backup) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    FloatButton(title: "Export Backup") {
                        prepareExport()
                    }
                    FloatButton(title: "Import Backup") {
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
        }
    }

    private var balanceSection: some View {
        settingsCard(title: "Balance", section: .balance) {
            VStack(spacing: 8) {
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

    private var reserveSection: some View {
        settingsCard(title: "Reserve", section: .reserve) {
            VStack(spacing: 8) {
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

    private var billsSection: some View {
        settingsCard(title: "\(account.name) Bills", section: .bills) {
            VStack(spacing: 0) {
                ForEach(account.bills) { bill in
                    itemRow(
                        title: bill.name,
                        subtitle: "Next: \(labelDate(BudgetMath.nextUnpaidBillDate(bill: bill, paidEarlyBills: account.paidEarlyBills))) · \(bill.frequency.rawValue)",
                        amount: money(bill.amount)
                    ) {
                        activeSheet = .editBill(bill)
                    }
		                }
		            }
	        } accessory: {
            iconAddButton(title: "Bill") {
                activeSheet = .newBill
            }
        }
    }

    private var incomeSection: some View {
        settingsCard(title: "\(account.name) Income", section: .income) {
            VStack(spacing: 0) {
                ForEach(account.income.filter { $0.label != "Confirmed balance" }) { income in
                    itemRow(
                        title: income.label,
                        subtitle: "Next: \(labelDate(BudgetMath.nextRecurringDate(startDate: income.startDate, frequency: income.frequency, currentDate: Date.todayString))) · \(income.frequency.rawValue)",
                        amount: money(income.amount)
                    ) {
                        activeSheet = .editIncome(income)
                    }
                }
            }
        } accessory: {
            iconAddButton(title: "Income") {
                activeSheet = .newIncome
            }
        }
    }

    private var accountsSection: some View {
        settingsCard(title: "Accounts", section: .accounts) {
            VStack(spacing: 0) {
	                ForEach(Array(store.budget.accounts.enumerated()), id: \.element.id) { index, item in
	                    HStack(spacing: 12) {
	                        Button {
	                            store.setActiveAccount(item.id)
	                        } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(accountMarkerColor(index))
                                        .frame(width: item.id == account.id ? 18 : 14, height: item.id == account.id ? 18 : 14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(.black.opacity(0.1), lineWidth: 0.5)
                                        )

                                    if editingAccountId == item.id {
                                        FloatTextField(placeholder: "Account name", text: $editingAccountName)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                saveEditedAccount()
                                            }
                                    } else {
                                        Text(item.name)
                                            .font(.system(size: 14, weight: item.id == account.id ? .semibold : .regular))
                                            .foregroundStyle(Color.floatText)
                                            .lineLimit(1)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if editingAccountId == item.id {
                                Button {
                                    saveEditedAccount()
                                } label: {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.floatText)
                            }

	                        if item.id == account.id {
                            Text("Active")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.floatTextFaint)
                        }

                        Button("Edit") {
                            editingAccountId = item.id
                            editingAccountName = item.name
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.floatText)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(.white.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.floatDivider, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if store.budget.accounts.count > 1 {
                            Button {
                                accountToDelete = item
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.floatTextFaint)
                        }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.floatDivider)
                            .frame(height: 0.5)
                    }
                }
            }
        } accessory: {
            iconAddButton(title: "Account") {
                activeSheet = .newAccount
            }
        }
    }

	    private func accountMarkerColor(_ index: Int) -> Color {
	        Color(hex: store.selectedPalette.marker(for: index))
	    }

    private var paletteSection: some View {
        settingsCard(title: "Palette", section: .palette) {
            palettePicker
        }
    }

    private var palettePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 6) {
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
                                Text(palette.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.floatTextFaint)
                            }

                            Spacer()

                            if store.selectedPalette.id == palette.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.floatTextMid)
                            }
                        }
                        .padding(.vertical, 7)
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

	    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { accountToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    accountToDelete = nil
                }
            }
        )
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

    private func saveEditedAccount() {
        let nextName = editingAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editingAccountId, !nextName.isEmpty {
            store.renameAccount(id: editingAccountId, name: nextName)
        }
        editingAccountId = nil
        editingAccountName = ""
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
                        Text(title.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(1.05)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.floatTextFaint)

                accessory()
            }
            .frame(height: 44)

            if expandedSections.contains(section) {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(.bottom, 18)
                .transition(.identity)
            }
        }
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.floatDivider.opacity(0.9))
                .frame(height: 0.5)
        }
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
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.floatText)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(.white.opacity(0.45))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.black.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
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
                        .stroke(Color.floatDivider, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.floatDivider)
                .frame(height: 0.5)
        }
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

enum SettingsSection: CaseIterable, Hashable {
    case backup
    case balance
    case reserve
    case bills
    case income
    case accounts
    case palette
}

enum SettingsSheet: Identifiable {
    case newBill
    case editBill(BudgetBill)
    case newIncome
    case editIncome(BudgetIncome)
    case newAccount

    var id: String {
        switch self {
        case .newBill: "new-bill"
        case .editBill(let bill): "edit-bill-\(bill.id)"
        case .newIncome: "new-income"
        case .editIncome(let income): "edit-income-\(income.id)"
        case .newAccount: "new-account"
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data("{}".utf8)) {
        self.data = data
    }

    init(budget: FloatBudget) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(budget)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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

struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var onSave: (String, Double) -> Void

    @State private var name = ""
    @State private var startingBalance = ""

    var body: some View {
        EditorShell(accountColor: accountColor, title: "New Account") {
            labeled("Account name") {
                FloatTextField(placeholder: "", text: $name)
            }
            labeled("Starting balance (optional)") {
                FloatTextField(placeholder: "", text: $startingBalance, keyboard: .decimalPad)
            }

            HStack(spacing: 10) {
                SheetActionButton(title: "Cancel", fill: .secondary) {
                    dismiss()
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { return }
                    onSave(trimmedName, Double(startingBalance) ?? 0)
                    dismiss()
                }
            }
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
            .scrollIndicators(.hidden)
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
            .foregroundStyle(Color.floatTextFaint)
        content()
    }
}
